# Godot AI Toolkit

An advanced, AI-powered dock for Godot 4 that brings code execution, 3D model generation, and procedural texturing directly into your editor. 

Stop copying and pasting code manually — let AI build your scenes, generate textures, and write EditorScripts for you in one click.

## ✨ Features

*   **🤖 AI Executor**: Paste AI-generated GDScript and run it directly in the editor context. Supports `EditorInterface`, current scene, and Undo/Redo.
*   **🌐 AI Browser**: Integrated webview (requires [Godot WRY](https://github.com/doceazedo/godot_wry)) to chat with ChatGPT/Claude without leaving Godot.
*   **📦 Model from AI**: Generate complex 3D models from JSON (GMesh DSL v1). Automatically creates meshes, materials, and UVs.
*   **🖼️ Texture AI**: Procedurally generate textures (noise, gradients, bricks, voronoi) and bake **Normal Maps** for realistic depth.
*   **🕒 History**: Browse, load, and manage previously generated models and textures.
*   **📤 Export**: Save your generated models as `.obj` (with `.mtl` materials) or `.tscn` scenes.
*   **📝 Built-in Prompts**: Ready-to-use prompts for AI to ensure it generates perfectly valid JSON every time.

## 📥 Installation

### Option 1: Godot Asset Library (Recommended)
1. Open Godot 4.
2. Go to the **AssetLib** tab.
3. Search for **Godot AI Toolkit**.
4. Download and install it.

### Option 2: Manual Installation
1. Download this repository as a `.zip` file.
2. Extract the `addons` folder into your Godot project's root directory.
3. Open **Project -> Project Settings -> Plugins** and enable **Godot AI Toolkit**.

### ⚠️ Dependency for the Browser Tab
To use the embedded web browser, you must install the [Godot WRY](https://github.com/doceazedo/godot_wry) GDExtension. 
*(The Executor, Model, and Texture tabs work perfectly without it).*

## 🛠️ How to Use

1. **Generate Code/Models/Textures:** Open the **Prompts** tab in the plugin, copy the prompt, and send it to ChatGPT or Claude.
2. **Run Code:** Paste the GDScript into the **Executor** tab and hit `Execute`.
3. **Build Models:** Paste the JSON into the **Build** tab and hit `Build`. The model will appear in your active 3D scene.
4. **Bake Textures:** Paste the JSON into the **Texture AI** tab, click `Bake Texture`, adjust the sliders (Normal Strength, Metallic, etc.), and click `Apply to Selection`.

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
