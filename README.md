# 📦 AppComu: Préstamo de Equipos UC

Aplicación móvil desarrollada en Flutter para gestionar el préstamo de equipos institucionales en la Universidad Continental, integrando autenticación institucional y administración por roles (estudiante, gestor). 

## 📲 Descripción

Esta aplicación permite a los estudiantes solicitar el préstamo de equipos (y accesorios) de manera digital y a los gestores monitorear el estado y la devolución de los mismos. La autenticación es mediante correo institucional o Google institucional. El sistema utiliza Firebase para la autenticación, base de datos y almacenamiento de imágenes.

---

## 📸 Capturas de Pantalla

> **(En proceso de culminar, aquí estarán las imágenes de las pantallas principales: Login, Perfil, Equipos disponibles, Solicitud de préstamo, Panel de gestor, etc.)**

---

## ⚙️ Tecnologías Usadas

- **Flutter** (UI cross-platform)
- **Firebase**  
  - Firestore (Base de datos)
  - Authentication (Email/Google)
  - Storage (Imágenes)
- **Google Maps** (ubicación en mapa)
- **Paquetes Flutter**:  
  - `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`,  
  - `carousel_slider`, `intl`, `mailer`, `google_maps_flutter`, etc.

---

## 📁 Estructura del Proyecto

```

├── lib/
│   ├── screens/                # Todas las pantallas principales
│   ├── utils/                  # Funciones y clases utilitarias
│   ├── firebase\_options.dart  # Configuración de Firebase
│   └── main.dart               # Entry point
├── android/                    # Proyecto nativo Android
├── ios/                        # Proyecto nativo iOS
├── pubspec.yaml                # Dependencias
└── README.md

````

---

## 🛠️ Cómo ejecutar el proyecto

1. **Clona el repositorio**
   ```sh
   git clone https://github.com/Kenss12345/app_comu.git
   cd appcomu

2. **Instala las dependencias**

   ```sh
   flutter pub get

3. **Configura Firebase**

   * Descarga el archivo de configuración de tu proyecto de Firebase (`google-services.json` para Android, `GoogleService-Info.plist` para iOS) y colócalo en el lugar correspondiente.
   * Edita/añade tus claves de API en `firebase_options.dart` si es necesario.

4. **Ejecuta la app**

   ```sh
   flutter run

---

## 🔄 Flujo de uso básico

1. **Splash Screen:** Verifica si el usuario ya está autenticado.
2. **Login/Register:** Autenticación por correo institucional o Google.
3. **Pantalla de Perfil:** Visualiza y edita datos personales, ve estado y puntos.
4. **Equipos Disponibles:** Filtra y busca equipos por categoría y disponibilidad.
5. **Equipos a Cargo:** Consulta los equipos actualmente prestados.
6. **Solicitud de Equipos:** Completa el formulario para solicitar equipos.
7. **Panel de Gestores:** Acceso especial para monitorear préstamos activos.

---

## 🔑 Estructura de Firestore y Storage

### Storage:

* `/equipos/` → Carpeta con imágenes de los equipos y accesorios.

### Firestore:

#### **Colección: equipos**

* `categoria`, `codigoUC`, `condicion`, `descripcion`, `estado`, `imagenes` (array de enlaces), `marca`, `modelo`, `nombre`, `numero`, `tiempoMax`, `tipoEquipo`.

#### **Colección: solicitudes**

* `asignatura`, `celular`, `dni`, `docente`, `email`, `equipos` (array de equipos solicitados),
  `fecha_devolucion`, `fecha_envio`, `fecha_prestamo`, `hora_salida`, `lugar`, `nombre`, `tipoUsuario`, `trabajo`, `uid`.

#### **Colección: usuarios**

* `TieneEquipo` (boolean), `TipoUser`, `acepto_terminos`, `celular`, `dni`, `email`, `equipo`, `fechaDevolucion`,
  `foto`, `nombre`, `puntos`, `rol`, `uid`.

---

## 🤝 Guía de colaboración

* **Ramas:**

  * `main`: rama estable.
  * `dev`: rama de desarrollo.
  * `feature/nombre-feature`: para nuevas funcionalidades.
  * `fix/nombre-fix`: para corrección de bugs.

* **Commits:**

  * Usa mensajes descriptivos y en presente. Ejemplo: `fix: corrige bug en login`

* **Pull Requests:**

  * Solicita revisión antes de mergear a `main` o `dev`.

* **Convenciones de código:**

  * Sigue la estructura y nombrado de archivos como en el proyecto actual.
  * Asegúrate de que tu código esté testeado y documentado.

---

## 📝 Licencia

> En proceso...

---

## 📚 Recursos y enlaces útiles

* [Documentación Flutter](https://docs.flutter.dev/)
* [Documentación Firebase](https://firebase.google.com/docs)
* [Repositorio de paquetes oficiales para las aplicaciones Dart y Flutter](https://pub.dev/)

---

## ✨ Créditos

Proyecto desarrollado por estudiantes de la Universidad Continental.

---