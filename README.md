# Pou Starter Godot

Godot 4 starter project for a Pou-like virtual pet game. Open this folder in Godot 4 and run `res://scenes/main/Main.tscn`.

## Scene Structure

```text
Main (Node) - scenes/main/Main.tscn
├── Background (ColorRect)
├── Pet (Node2D instance)
│   ├── AnimatedSprite2D
│   └── EatTimer
├── HUD (CanvasLayer instance)
├── Shop (Control instance)
└── Minigame (Control instance)
```

## File Structure

```text
project.godot
assets/
  icon.svg
  items/coin.svg
  pet/*.svg
scenes/
  main/Main.tscn
  minigame/Minigame.tscn
  pet/Pet.tscn
  shop/Shop.tscn
  ui/HUD.tscn
scripts/
  main/Main.gd
  minigame/Minigame.gd
  pet/Pet.gd
  save/SaveManager.gd
  shop/Shop.gd
  ui/HUD.gd
```

## Persistence

Save data is stored in `user://save.json` through the `SaveManager` autoload.
