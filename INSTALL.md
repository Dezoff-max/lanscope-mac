# LanScope Mac Installation

## Русский

1. Откройте `LanScope Mac.dmg`.
2. Перетащите `LanScope Mac.app` в папку `Applications`.
3. Запустите приложение из `Applications`.

Если macOS блокирует запуск неподписанного приложения, сначала попробуйте безопасный способ:

1. Откройте `Applications`.
2. Нажмите правой кнопкой на `LanScope Mac.app`.
3. Выберите `Open`.
4. Подтвердите запуск.

Если приложение все равно не запускается и вы доверяете этому DMG, можно временно отключить Gatekeeper:

```bash
sudo spctl --master-disable
```

После первого запуска приложения включите Gatekeeper обратно:

```bash
sudo spctl --master-enable
```

Важно: не оставляйте Gatekeeper отключенным постоянно. Эта настройка влияет на безопасность всей системы.

## English

1. Open `LanScope Mac.dmg`.
2. Drag `LanScope Mac.app` to the `Applications` folder.
3. Launch the app from `Applications`.

If macOS blocks the unsigned app, try the safer method first:

1. Open `Applications`.
2. Right-click `LanScope Mac.app`.
3. Choose `Open`.
4. Confirm the launch.

If the app still does not launch and you trust this DMG, you can temporarily disable Gatekeeper:

```bash
sudo spctl --master-disable
```

After the first launch, enable Gatekeeper again:

```bash
sudo spctl --master-enable
```

Important: do not leave Gatekeeper disabled permanently. This setting affects the security of the whole system.
