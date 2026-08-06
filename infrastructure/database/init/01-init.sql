-- Initialisation PostgreSQL de développement (exécuté au premier démarrage).

-- Extensions utiles à l'ensemble du schéma.
-- gen_random_uuid() est natif depuis PostgreSQL 13 ; citext servira aux
-- e-mails insensibles à la casse.
CREATE EXTENSION IF NOT EXISTS citext;

-- Base dédiée aux tests d'intégration/e2e.
CREATE DATABASE carlys_test OWNER carlys;
\connect carlys_test
CREATE EXTENSION IF NOT EXISTS citext;
