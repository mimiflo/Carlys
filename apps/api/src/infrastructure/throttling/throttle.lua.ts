/**
 * Script Lua du compteur de débit partagé.
 *
 * POURQUOI UN SCRIPT, ET PAS TROIS ALLERS-RETOURS. « Lire le compteur,
 * décider, écrire » exécuté par plusieurs réplicas en même temps laisse passer
 * plus de requêtes que la limite : entre la lecture et l'écriture, un autre
 * réplica a compté aussi. Redis exécute un script sans rien intercaler : la
 * décision et l'incrément sont un seul évènement, quel que soit le nombre de
 * réplicas.
 *
 * Les durées entrent et sortent en MILLISECONDES ; c'est l'appelant qui les
 * convertit en secondes pour @nestjs/throttler.
 *
 * Rendu : { coups, ms avant remise à zéro, bloqué (0|1), ms avant déblocage }
 */
export const THROTTLE_LUA = `
local hitsKey = KEYS[1]
local blockKey = KEYS[2]
local ttlMs = tonumber(ARGV[1])
local limit = tonumber(ARGV[2])
local blockMs = tonumber(ARGV[3])

-- Déjà bloqué : on ne compte pas ce coup. Sans ce retour anticipé, marteler
-- l'API pendant un blocage repousserait indéfiniment le déblocage.
local blockRemaining = redis.call('PTTL', blockKey)
if blockRemaining > 0 then
  local hits = tonumber(redis.call('GET', hitsKey))
  if hits == nil then
    hits = limit + 1
  end
  return { hits, blockRemaining, 1, blockRemaining }
end

local hits = redis.call('INCR', hitsKey)
if hits == 1 then
  redis.call('PEXPIRE', hitsKey, ttlMs)
end

local remaining = redis.call('PTTL', hitsKey)
if remaining < 0 then
  -- Clé sans expiration (INCR concurrent perdu, ou clé héritée) : lui en
  -- poser une plutôt que de la laisser compter pour l'éternité.
  redis.call('PEXPIRE', hitsKey, ttlMs)
  remaining = ttlMs
end

if hits > limit then
  redis.call('SET', blockKey, 1, 'PX', blockMs)
  -- Les coups expirent AVEC le blocage. Sinon la fenêtre, déjà pleine au
  -- moment du déblocage, rebloquerait dès la requête suivante — le blocage
  -- durerait la fenêtre, pas la durée annoncée.
  redis.call('PEXPIRE', hitsKey, blockMs)
  return { hits, blockMs, 1, blockMs }
end

return { hits, remaining, 0, 0 }
`;
