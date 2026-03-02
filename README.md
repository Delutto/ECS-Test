# Pascal2D Engine – Super Mario World Demo

## Visão Geral

Engine 2D em Object Pascal com arquitetura **ECS (Entity-Component-System)**,
utilizando **ray4laz** (bindings raylib para Free Pascal / Lazarus).

---

## Estrutura do Projeto

```
Pascal2D/
├── mario_demo.lpr          ← Programa principal
├── mario_demo.lpi          ← Projeto Lazarus
├── Engine/
│   ├── Core/               ← Núcleo ECS
│   │   ├── P2D.Core.Types      ← Tipos base (TVector2, TRectF, TColor…)
│   │   ├── P2D.Core.Component  ← Classe base de componentes
│   │   ├── P2D.Core.Entity     ← Entidade + EntityManager
│   │   ├── P2D.Core.System     ← Classe base de sistemas
│   │   ├── P2D.Core.World      ← Orquestrador ECS
│   │   └── P2D.Core.Engine     ← Loop principal + raylib
│   ├── Components/         ← Componentes de dados
│   │   ├── Transform, Sprite, Animation
│   │   ├── RigidBody, Collider
│   │   ├── Camera2D, TileMap, Tags
│   └── Systems/            ← Lógica de sistemas
│       ├── Physics, Collision
│       ├── Animation, Render
│       ├── Camera, TileMap
│   └── Utils/
│       ├── P2D.Utils.Math      ← Funções matemáticas
│       └── P2D.Utils.Logger    ← Logger singleton
└── Demo/
    └── Mario/
        ├── Mario.ProceduralArt ← Geração de assets via código
        ├── Mario.Entities      ← Fábricas de entidades
        ├── Mario.Level         ← Dados do nível
        ├── Mario.Systems.*     ← Sistemas específicos do jogo
        └── Mario.Game          ← Orquestrador do demo
```

---

## Pré-requisitos

1. **Lazarus IDE** ≥ 3.0 + **Free Pascal Compiler** ≥ 3.2
2. **ray4laz** instalado via Lazarus Online Package Manager
   - `Package → Online Package Manager → ray4laz → Install`

---

## Como Compilar

1. Abra `mario_demo.lpi` no Lazarus
2. Confirme que o pacote `ray4laz` está instalado
3. `Run → Build` (Shift+F9) ou `Run → Run` (F9)

---

## Controles do Demo

| Tecla                       | Ação              |
|-----------------------------|-------------------|
| ← → / A D                  | Mover             |
| Espaço / W / ↑              | Pular             |
| Shift esquerdo / Z          | Correr            |
| R                           | Reiniciar level   |
| Alt+F4 / fechar janela      | Sair              |

---

## Arquitetura ECS

### Entity
Um simples `Cardinal` (ID). Criado pelo `TEntityManager`.

### Component (TComponent2D)
Apenas **dados**. Exemplos:
- `TTransformComponent` – posição, escala, rotação
- `TRigidBodyComponent` – velocidade, gravidade
- `TColliderComponent`  – caixa de colisão + tag
- `TSpriteComponent`    – textura + região de fonte
- `TAnimationComponent` – spritesheet animado

### System (TSystem2D)
Toda a **lógica**. Cada sistema filtra entidades e opera sobre componentes:
- `TPhysicsSystem`   – integração de velocidade e gravidade
- `TCollisionSystem` – resposta a colisões com tiles e entidades
- `TAnimationSystem` – avança frames de animação
- `TCameraSystem`    – câmera suave com limites de mundo
- `TRenderSystem`    – desenha sprites via `DrawTexturePro`
- `TTileMapSystem`   – renderiza o mapa de tiles

### World (TWorld)
Orquestra entidades e sistemas. A cada frame:
1. `Update(delta)` → todos os sistemas em ordem de `Priority`
2. Purga entidades destruídas
3. `Render()` → sistemas com lógica de desenho

---

## Assets Procedurais

O demo não usa arquivos externos de imagem. A unit `Mario.ProceduralArt`
gera texturas diretamente na GPU via `GenImageColor` + `ImageDrawPixel`
do raylib, dispensando arquivos de assets.