-- 24.11.2026 (Version 72): Spieler-Angriffs-Elo = EIN Update je Angriffslauf.
--  * neue Spalte spieler_elo.duelle  (spiele = Läufe, siege = geknackte Verteidigungen, duelle = angetroffene Verteidigungen)
--  * neue Tabelle angriff_laeufe     (Lauf-Nummern, damit eine doppelte Meldung nicht doppelt zählt)
--  * neue Funktion angriff_lauf_melden (S und E je Verteidigung, nach Budget gewichtet, K 64)
--  * duell_melden: aktualisiert die Spieler-Angriffs-Elo nicht mehr (alte Browser-Versionen zählen damit nicht für die
--    Spieler-Elo); Verteidigung zählt zusätzlich duelle
alter table spieler_elo add column if not exists duelle integer not null default 0;
update spieler_elo set duelle = spiele where duelle = 0;

create table if not exists angriff_laeufe (
  lauf text primary key,
  profil text not null,
  erstellt timestamptz not null default now());
alter table angriff_laeufe enable row level security;

create or replace function public.angriff_lauf_melden(p_profil text, p_spieler text, p_lauf text, p_duelle jsonb)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  k constant double precision := 64;
  sieg_ab constant double precision := 0.749;
  prof text := left(coalesce(p_profil, ''), 32);
  name text := left(coalesce(nullif(btrim(p_spieler), ''), 'Gast'), 16);
  r0 double precision;
  vor double precision;
  neu double precision;
  zs double precision := 0;
  ze double precision := 0;
  zw double precision := 0;
  n_duelle integer := 0;
  n_geknackt integer := 0;
  it jsonb;
  v_id uuid;
  v_s double precision;
  v_w double precision;
  rd double precision;
  pv text;
  e double precision;
begin
  if prof = '' or prof = 'pool' then return null; end if;
  if p_lauf is null or char_length(p_lauf) < 8 or char_length(p_lauf) > 80 then raise exception 'lauf'; end if;
  if p_duelle is null or jsonb_typeof(p_duelle) <> 'array' or jsonb_array_length(p_duelle) = 0 or jsonb_array_length(p_duelle) > 25 then
    raise exception 'duelle';
  end if;
  insert into angriff_laeufe (lauf, profil) values (p_lauf, prof) on conflict do nothing;
  if not found then return null; end if;   -- diese Meldung kam schon an
  select elo into r0 from spieler_elo where profil = prof and art = 'angriff' for update;
  if not found then
    insert into spieler_elo (profil, art, spieler) values (prof, 'angriff', name);
    r0 := 1000;
  end if;
  vor := r0;
  for it in select value from jsonb_array_elements(p_duelle) loop
    v_id := (it->>'id')::uuid;
    v_s := (it->>'s')::double precision;
    v_w := coalesce((it->>'w')::double precision, 1);
    if v_s is null or v_s < 0 or v_s > 1 then raise exception 'ergebnis'; end if;
    v_w := greatest(0.0001, least(v_w, 100000));
    select elo, coalesce(profil, '') into rd, pv from phantome where id = v_id and art = 'verteidigung';
    if not found then continue; end if;
    if pv = prof then continue; end if;   -- eigene Verteidigung zählt nicht
    e := 1.0 / (1.0 + power(10.0, (rd - r0) / 400.0));   -- Erwartung immer gegen die Elo vom Lauf-Start
    zs := zs + v_w * v_s;
    ze := ze + v_w * e;
    zw := zw + v_w;
    n_duelle := n_duelle + 1;
    if v_s >= sieg_ab then n_geknackt := n_geknackt + 1; end if;
  end loop;
  if zw = 0 then return null; end if;
  neu := r0 + k * (zs - ze) / zw;
  update spieler_elo set elo = neu, elo_max = greatest(elo_max, neu), spiele = spiele + 1,
    siege = siege + n_geknackt, duelle = duelle + n_duelle, spieler = name, aktualisiert = now()
  where profil = prof and art = 'angriff';
  return jsonb_build_object('vorher', vor, 'nachher', neu, 'duelle', n_duelle, 'geknackt', n_geknackt);
end $function$;

grant execute on function public.angriff_lauf_melden(text, text, text, jsonb) to anon, authenticated;

-- duell_melden (gleiche Signatur): Spieler-Angriffs-Elo wird hier nicht mehr geändert (macht angriff_lauf_melden),
-- Verteidigungs-Elo zählt zusätzlich duelle.
create or replace function public.duell_melden(p_angriff uuid, p_verteidigung uuid, p_ergebnis double precision, p_wertung integer, p_spieler text, p_profil text, p_mensch text default null::text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  k constant double precision := 32;
  sieg_ab constant double precision := 0.749;
  ra double precision := 1000;  pa text := '';
  rd double precision := 1000;  pv text := '';
  rh double precision := 1000;
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
  if prof = '' or prof = 'pool' then seite := null; end if;
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
  if p_angriff is not null then
    gegner_r := case when seite = 'verteidigung' then rh when p_verteidigung is not null then rd else 1000 end;
    besitzer := case when seite = 'verteidigung' then prof else pv end;
    if not (besitzer <> '' and besitzer = pa) then
      update phantome set elo = elo + k * (s - 1.0 / (1.0 + power(10.0, (gegner_r - ra) / 400.0))),
        spiele = spiele + 1, siege = siege + (case when s >= sieg_ab then 1 else 0 end),
        wertung = greatest(wertung, greatest(0, least(coalesce(p_wertung, 0), 1000000)))
      where id = p_angriff;
    end if;
  end if;
  if p_verteidigung is not null then
    gegner_r := case when seite = 'angriff' then rh when p_angriff is not null then ra else 1000 end;
    besitzer := case when seite = 'angriff' then prof else pa end;
    if not (besitzer <> '' and besitzer = pv) then
      update phantome set elo = elo + k * ((1 - s) - (1 - 1.0 / (1.0 + power(10.0, (rd - gegner_r) / 400.0)))),
        spiele = spiele + 1, siege = siege + (case when s < sieg_ab then 1 else 0 end)
      where id = p_verteidigung;
    end if;
  end if;
  -- Spieler-Angriffs-Elo: nicht hier, sondern einmal je Lauf in angriff_lauf_melden.
  if seite = 'verteidigung' and p_angriff is not null and pa <> prof then
    update spieler_elo set elo = elo + k * ((1 - s) - (1 - 1.0 / (1.0 + power(10.0, (rh - ra) / 400.0)))),
      elo_max = greatest(elo_max, elo + k * ((1 - s) - (1 - 1.0 / (1.0 + power(10.0, (rh - ra) / 400.0))))),
      spiele = spiele + 1, duelle = duelle + 1, siege = siege + (case when s < sieg_ab then 1 else 0 end), spieler = name, aktualisiert = now()
    where profil = prof and art = 'verteidigung';
  end if;
end $function$;
