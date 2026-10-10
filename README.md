# Steal a Fossil

Jeu Roblox de Snaky, calqué sur Steal an Egg : cours sur la route préhistorique, arrache des blocs fossiles gardés par des dinos vivants, ramène-les dans ton parc, réanime-les et fusionne-les en hybrides.

- Design du jeu : [docs/GDD.md](docs/GDD.md)
- Plan de production en threads : [docs/PROMPT_MAITRE.md](docs/PROMPT_MAITRE.md)
- Comment le code est organisé et comment ajouter un service, un controller, une config, des remotes, des données ou un test : [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

## Lancer le jeu dans Studio

1. Installer les outils : `rokit install` (avec [Rokit](https://github.com/rojo-rbx/rokit)), ou sans Rokit `python3 tools/setup_tools.py` (tout va dans `tools/.bin`).
2. `rojo serve` dans ce dossier, puis Connect dans le plugin Rojo de Studio.
3. Play. Tests en jeu : barre de commande en vue serveur, `game.ServerScriptService.FossilDebug:Invoke("all")`, qui doit finir par `@@ all: N OK / 0 FAIL`.

Studio lit les vraies sauvegardes mais ne les écrit jamais (`Config.Core.Data.SaveInStudio = false`).

## Vérifier le code

```
python3 tools/check.py
```

Analyse stricte (luau-lsp), selene, tests hors Studio (`tools/luau_tests/run.py`) et build Rojo. La CI GitHub lance la même chose sur chaque PR.
