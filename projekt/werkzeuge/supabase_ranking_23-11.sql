-- 23.11.2026 (Paul): Phantom-Ranking – Plätze je Spieler (Archiv), Spieler-Elo, gleiche Profil-ID zählt nicht,
-- neue Ergebnis-Skala (Sieg ab 0,749). ERSETZT werkzeuge/supabase_duell_23-11.sql (dieselbe Sieg-Grenze ist hier enthalten).
-- ERST einspielen, wenn die Web-Version mit dem neuen online.gd / main.gd / startmenue.gd / phantom.gd veröffentlicht wird.
-- Alte Spielstände bleiben lauffähig: duell_melden nimmt p_mensch als optionalen siebten Wert (Standard null = wie bisher).

-- 1) Archiv: verdrängte Phantome bleiben erhalten, stehen aber nicht mehr im Pool und nicht in der Rangliste
alter table public.phantome add column if not exists archiviert boolean not null default false;

-- 2) Spieler-Elo je Profil und Seite (angriff = der Spieler greift an, verteidigung = er verteidigt)
create table if not exists public.spieler_elo (
  profil text not null,
  art text not null check (art in ('angriff', 'verteidigung')),
  spieler text not null default 'Gast',
  elo double precision not null default 1000,
  spiele integer not null default 0,
  siege integer not null default 0,
  aktualisiert timestamptz not null default now(),
  primary key (profil, art)
);
alter table public.spieler_elo enable row level security;
drop policy if exists "spieler_elo lesen" on public.spieler_elo;
create policy "spieler_elo lesen" on public.spieler_elo for select to anon, authenticated using (true);
grant select on public.spieler_elo to anon, authenticated;

-- 3) Duelle merken, ob und auf welcher Seite ein Mensch beteiligt war
alter table public.duelle add column if not exists mensch text;
alter table public.duelle add column if not exists elo_mensch_vorher double precision;

-- 4) duell_melden neu (mit optionalem p_mensch)
drop function if exists public.duell_melden(uuid, uuid, double precision, integer, text, text);
create or replace function public.duell_melden(p_angriff uuid, p_verteidigung uuid, p_ergebnis double precision, p_wertung integer,
    p_spieler text, p_profil text, p_mensch text default null)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  k constant double precision := 32;
  sieg_ab constant double precision := 0.749;     -- ab hier zählt ein Duell als Sieg des Angreifers (sonst „gehalten“)
  ra double precision := 1000;  pa text := '';    -- Angriffs-Phantom: Elo, Profil
  rd double precision := 1000;  pv text := '';    -- Verteidigungs-Phantom: Elo, Profil
  rh double precision := 1000;                     -- Spieler-Elo (Mensch)
  seite text := case when p_mensch in ('angriff', 'verteidigung') then p_mensch else null end;
  prof text := left(coalesce(p_profil, ''), 32);
  name text := left(coalesce(nullif(btrim(p_spieler), ''), 'Gast'), 16);
  s double precision;
  gegner_r double precision;
  besitzer text;
begin
  if p_angriff is null and p_verteidigung is null then return; end if;
  if p_ergebnis is null or p_ergebnis < 0 or p_ergebnis > 1 then raise exception 'ergebnis'; end if;
  s := p_ergebnis;
  if prof = '' or prof = 'pool' then seite := null; end if;   -- ohne Profil keine Spieler-Elo
  if p_angriff is not null then
    select elo, coalesce(profil, '') into ra, pa from phantome where id = p_angriff and art = 'angriff' for update;
    if not found then raise exception 'angriff'; end if;
  end if;
  if p_verteidigung is not null then
    select elo, coalesce(profil, '') into rd, pv from phantome where id = p_verteidigung and art = 'verteidigung' for update;
    if not found then raise exception 'verteidigung'; end if;
  end if;
  if seite is not null then
    select elo into rh from spieler_elo where profil = prof and art = seite for update;
    if not found then
      insert into spieler_elo (profil, art, spieler) values (prof, seite, name);
      rh := 1000;
    end if;
  end if;

  insert into duelle (angriff, verteidigung, ergebnis, wertung, spieler, profil, elo_angriff_vorher, elo_verteidigung_vorher, mensch, elo_mensch_vorher)
  values (p_angriff, p_verteidigung, s, greatest(0, least(coalesce(p_wertung, 0), 1000000)), name, prof, ra, rd, seite,
          case when seite is null then null else rh end);

  -- Angriffs-Phantom: gegen das Verteidigungs-Phantom bzw. (Mensch verteidigt) gegen den Spieler
  if p_angriff is not null then
    gegner_r := case when seite = 'verteidigung' then rh when p_verteidigung is not null then rd else 1000 end;
    besitzer := case when seite = 'verteidigung' then prof else pv end;
    if not (besitzer <> '' and besitzer = pa) then   -- gleiche Profil-ID zählt nicht
      update phantome set elo = elo + k * (s - 1.0 / (1.0 + power(10.0, (gegner_r - ra) / 400.0))),
        spiele = spiele + 1, siege = siege + (case when s >= sieg_ab then 1 else 0 end),
        wertung = greatest(wertung, greatest(0, least(coalesce(p_wertung, 0), 1000000)))
      where id = p_angriff;
    end if;
  end if;

  -- Verteidigungs-Phantom: gegen den angreifenden Spieler bzw. das Angriffs-Phantom
  if p_verteidigung is not null then
    gegner_r := case when seite = 'angriff' then rh when p_angriff is not null then ra else 1000 end;
    besitzer := case when seite = 'angriff' then prof else pa end;
    if not (besitzer <> '' and besitzer = pv) then
      update phantome set elo = elo + k * ((1 - s) - (1 - 1.0 / (1.0 + power(10.0, (rd - gegner_r) / 400.0)))),
        spiele = spiele + 1, siege = siege + (case when s < sieg_ab then 1 else 0 end)
      where id = p_verteidigung;
    end if;
  end if;

  -- Spieler-Elo: der Mensch gegen das gegnerische Phantom (nicht gegen eigene)
  if seite = 'angriff' and p_verteidigung is not null and pv <> prof then
    update spieler_elo set elo = elo + k * (s - 1.0 / (1.0 + power(10.0, (rd - rh) / 400.0))),
      spiele = spiele + 1, siege = siege + (case when s >= sieg_ab then 1 else 0 end), spieler = name, aktualisiert = now()
    where profil = prof and art = 'angriff';
  elsif seite = 'verteidigung' and p_angriff is not null and pa <> prof then
    update spieler_elo set elo = elo + k * ((1 - s) - (1 - 1.0 / (1.0 + power(10.0, (rh - ra) / 400.0)))),
      spiele = spiele + 1, siege = siege + (case when s < sieg_ab then 1 else 0 end), spieler = name, aktualisiert = now()
    where profil = prof and art = 'verteidigung';
  end if;
end $function$;
grant execute on function public.duell_melden(uuid, uuid, double precision, integer, text, text, text) to anon, authenticated;

-- 5) Eigenes Phantom archivieren (Platz frei machen). Nur der Besitzer (gleiche Profil-ID) kann das.
create or replace function public.phantom_archivieren(p_id uuid, p_profil text)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if coalesce(p_profil, '') in ('', 'pool') then return false; end if;
  update phantome set archiviert = true where id = p_id and profil = p_profil and not archiviert;
  return found;
end $function$;
grant execute on function public.phantom_archivieren(uuid, text) to anon, authenticated;
