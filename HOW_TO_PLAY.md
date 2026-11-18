# How to play / Как запустить

**[Русский](#русский) · [English](#english)**

---

## Русский

### Игры и файлы запуска

- **Stellar Drift (Low)** (Godot 4.7.2): [StellarDrift-Low-Windows-x64.zip](https://github.com/Cryptopiy/Claude-Sonnet-5.5-Effort-Test-Space-Games/releases/download/v1.0/StellarDrift-Low-Windows-x64.zip) → запустите `StellarDrift.exe`
- **Solace (Medium)** (Godot 4.7.2): [Solace-Medium-Windows-x64.zip](https://github.com/Cryptopiy/Claude-Sonnet-5.5-Effort-Test-Space-Games/releases/download/v1.0/Solace-Medium-Windows-x64.zip) → запустите `Solace.exe`
- **Aether Drift (High)** (Godot 4.7.2): [AetherDrift-High-Windows-x64.zip](https://github.com/Cryptopiy/Claude-Sonnet-5.5-Effort-Test-Space-Games/releases/download/v1.0/AetherDrift-High-Windows-x64.zip) → запустите `AetherDrift.exe`
- **Starfarer (XHigh)** (Godot 4.7.2): [Starfarer-XHigh-Windows-x64.zip](https://github.com/Cryptopiy/Claude-Sonnet-5.5-Effort-Test-Space-Games/releases/download/v1.0/Starfarer-XHigh-Windows-x64.zip) → запустите `Starfarer.exe`
- **Wayfarer (Max)** (Godot 4.7.2): [Wayfarer-Max-Windows-x64.zip](https://github.com/Cryptopiy/Claude-Sonnet-5.5-Effort-Test-Space-Games/releases/download/v1.0/Wayfarer-Max-Windows-x64.zip) → запустите `Wayfarer.exe`
- **Horizon Drift (Ultracode)** (Godot 4.7.2): [HorizonDrift-Ultracode-Windows-x64.zip](https://github.com/Cryptopiy/Claude-Sonnet-5.5-Effort-Test-Space-Games/releases/download/v1.0/HorizonDrift-Ultracode-Windows-x64.zip) → запустите `HorizonDrift.exe`

### Готовая сборка для Windows (1 файл)

1. Скачайте zip игры (ссылка выше или вкладка **Releases** справа на странице репозитория).
2. Нажмите по zip правой кнопкой → **Извлечь всё…** Не запускайте игру прямо из архива.
3. Откройте распакованную папку и дважды кликните `.exe` с названием игры. Всё — установка не нужна.
4. Если Windows показала «Windows защитила ваш компьютер» — это потому, что сборка не подписана платным сертификатом. Нажмите **Подробнее → Выполнить в любом случае**. Исходный код каждой игры лежит в этом репозитории.
5. Проверить, что файл не изменён: в PowerShell выполните `Get-FileHash .\ИмяФайла.zip` и сравните с `SHA256SUMS.txt` в релизе.

Требования: Windows 10/11 64-bit, видеокарта с поддержкой DirectX 12 / Vulkan. Для игр на Unreal Engine при ошибке про отсутствующие DLL установите Microsoft Visual C++ Redistributable (x64) с сайта Microsoft.

### Как открыть исходники в движке

**Godot (4.7.2):** скачайте Godot той же версии с godotengine.org (обычная версия, не .NET, если в проекте нет C#). В Project Manager нажмите **Import**, выберите `project.godot` в папке игры, затем **Run (F5)**. Первое открытие может занять пару минут — Godot импортирует ресурсы.

### Сделать такую же игру с ИИ

Промпты лежат в папке [prompts/](prompts) (если есть), а гайд по связке Claude/Codex + движок + Blender MCP — в [BLENDER_MCP_GUIDE.md](BLENDER_MCP_GUIDE.md).

---

## English

### Games and launch files

- **Stellar Drift (Low)** (Godot 4.7.2): [StellarDrift-Low-Windows-x64.zip](https://github.com/Cryptopiy/Claude-Sonnet-5.5-Effort-Test-Space-Games/releases/download/v1.0/StellarDrift-Low-Windows-x64.zip) → run `StellarDrift.exe`
- **Solace (Medium)** (Godot 4.7.2): [Solace-Medium-Windows-x64.zip](https://github.com/Cryptopiy/Claude-Sonnet-5.5-Effort-Test-Space-Games/releases/download/v1.0/Solace-Medium-Windows-x64.zip) → run `Solace.exe`
- **Aether Drift (High)** (Godot 4.7.2): [AetherDrift-High-Windows-x64.zip](https://github.com/Cryptopiy/Claude-Sonnet-5.5-Effort-Test-Space-Games/releases/download/v1.0/AetherDrift-High-Windows-x64.zip) → run `AetherDrift.exe`
- **Starfarer (XHigh)** (Godot 4.7.2): [Starfarer-XHigh-Windows-x64.zip](https://github.com/Cryptopiy/Claude-Sonnet-5.5-Effort-Test-Space-Games/releases/download/v1.0/Starfarer-XHigh-Windows-x64.zip) → run `Starfarer.exe`
- **Wayfarer (Max)** (Godot 4.7.2): [Wayfarer-Max-Windows-x64.zip](https://github.com/Cryptopiy/Claude-Sonnet-5.5-Effort-Test-Space-Games/releases/download/v1.0/Wayfarer-Max-Windows-x64.zip) → run `Wayfarer.exe`
- **Horizon Drift (Ultracode)** (Godot 4.7.2): [HorizonDrift-Ultracode-Windows-x64.zip](https://github.com/Cryptopiy/Claude-Sonnet-5.5-Effort-Test-Space-Games/releases/download/v1.0/HorizonDrift-Ultracode-Windows-x64.zip) → run `HorizonDrift.exe`

### Ready-made Windows build (1 file)

1. Download the game's zip (link above or the **Releases** tab on the right side of the repo page).
2. Right-click the zip → **Extract All…** Do not run the game from inside the archive.
3. Open the extracted folder and double-click the `.exe` named after the game. That's it — no installation.
4. If Windows shows “Windows protected your PC”, it's because the build isn't signed with a paid certificate. Click **More info → Run anyway**. The full source code of every game is in this repo.
5. To verify the download: in PowerShell run `Get-FileHash .\FileName.zip` and compare with `SHA256SUMS.txt` in the release.

Requirements: Windows 10/11 64-bit, a GPU with DirectX 12 / Vulkan support. For Unreal Engine games, if you get a missing-DLL error, install the Microsoft Visual C++ Redistributable (x64) from Microsoft's website.

### Open the source in the engine

**Godot (4.7.2):** download the same Godot version from godotengine.org (standard build, not .NET unless the project uses C#). In the Project Manager click **Import**, select `project.godot` in the game folder, then **Run (F5)**. The first import can take a couple of minutes.

### Make a game like this with AI

The prompts are in [prompts/](prompts) (if present), and the Claude/Codex + engine + Blender MCP setup guide is in [BLENDER_MCP_GUIDE.md](BLENDER_MCP_GUIDE.md).
