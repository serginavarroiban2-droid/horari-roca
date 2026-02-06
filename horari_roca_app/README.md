# Horari Roca - App Mòbil

Aplicació mòbil Flutter per gestionar els horaris de treball de Roca & Rambla.

## Característiques

- 📅 **Vista Setmanal**: Veure tots els torns de la setmana organitzats per dia
- 👤 **Els Meus Torns**: Vista personal dels pròxims 14 dies
- 🏪 **Ubicació**: Diferenciació entre Roca i Rambla
- 🌙 **Mode Fosc**: Tema clar i fosc
- 🔐 **Autenticació**: Login segur amb Supabase

## Requisits

- Flutter 3.x
- Connexió a Internet

## Instal·lació

1. Assegura't de tenir Flutter instal·lat
2. Executa:
   ```bash
   cd horari_roca_app
   flutter pub get
   ```

## Executar

### Android (Emulador o dispositiu)
```bash
flutter run
```

### iOS (Mac amb Xcode)
```bash
flutter run
```

### Web (per proves)
```bash
flutter run -d chrome
```

## Compilar APK (Android)

```bash
flutter build apk --release
```

L'APK es trobarà a: `build/app/outputs/flutter-apk/app-release.apk`

## Estructura del Projecte

```
lib/
├── config/         # Configuració (Supabase)
├── models/         # Models de dades
├── providers/      # Gestió d'estat (Riverpod)
├── screens/        # Pantalles de l'app
├── theme/          # Temes i estils
└── main.dart       # Punt d'entrada
```

## Tecnologies

- **Flutter** - Framework UI
- **Supabase** - Backend i Autenticació
- **Riverpod** - Gestió d'estat
- **Google Fonts** - Tipografia moderna
