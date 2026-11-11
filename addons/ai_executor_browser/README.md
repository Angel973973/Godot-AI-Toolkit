# Godot AI Toolkit

An advanced AI-powered dock for Godot 4.3+ that brings code execution, 3D model generation, and procedural texturing directly into your editor.

## Features
- **AI Executor**: Run GDScript directly in the editor context with Undo/Redo support.
- **AI Browser**: Integrated webview (requires [Godot WRY](https://github.com/doceazedo/godot_wry)) to chat with ChatGPT/Claude.
- **Model from AI**: Generate 3D models from JSON (GMesh DSL v1) with automatic UVs and materials.
- **History**: Browse and reload previously generated models and textures.
- **Export**: Save your generated models as `.obj` (with `.mtl`) or `.tscn` scenes.
- **Texture AI**: Procedurally generate textures (noise, gradients, bricks, voronoi) and bake Normal Maps.
- **Texture Settings**: Adjust metallic, roughness, UV scale, brightness, and normal strength in real-time.

## Installation
1. Copy the `addons/ai_executor_browser` folder into your project.
2. Enable the plugin in **Project -> Project Settings -> Plugins**.
3. (Optional) For the Browser tab, install the **Godot WRY** GDExtension.

## Usage
Use the built-in **Prompts** tab to copy the correct JSON schema instructions to ChatGPT or Claude, then paste the generated JSON into the respective tabs.

## License
MIT License.
