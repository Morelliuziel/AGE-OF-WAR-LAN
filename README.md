# Age Of War 1v1 - Multijugador LAN

Implementación multijugador en red local (LAN) inspirada en el clásico juego de estrategia y defensa de bases **Age of War**, desarrollado íntegramente en **Processing (Java)**.

El proyecto utiliza una arquitectura **Cliente-Servidor Autoritativo** con descubrimiento automático en la red local (sin necesidad de configurar direcciones IP manualmente), evolución a través de 3 eras tecnológicas, sistema de economía activa/pasiva y animaciones completas por cuadros.

## 📋 Requisitos Previos

* **Processing 4** (o Processing 3.5.4+): [Descargar desde processing.org](https://processing.org/download)

* **Librería de Red (`processing.net`)**: Viene incluida de forma nativa en la instalación estándar de Processing.

* **Red Local (LAN / Wi-Fi)**: Ambas computadoras deben estar conectadas a la misma red local y tener habilitados los puertos **UDP 8888** y **TCP 12345** en el Firewall de Windows/Linux/macOS.

## 🚀 Guía de Instalación y Ejecución

### 1. Extracción del Proyecto

1. Descarga el archivo comprimido (`AgeOfWar1v1.zip`).

2. Extrae todo su contenido asegurándote de mantener intacta la estructura de carpetas. El nombre de la carpeta principal **debe coincidir exactamente** con el nombre del archivo `.pde`:

   ```
   AgeOfWar1v1/
   ├── AgeOfWar1v1.pde               # Código fuente principal del juego y motor de red
   ├── InstalarSpritesOriginales.bat # Ejecutable automático para Windows
   ├── InstalarSpritesOriginales.ps1 # Script PowerShell de extracción/organización de sprites
   └── data/
       └── original/                 # Carpeta de recursos gráficos del juego
   
   ```

### 2. Instalación y Configuración de los Sprites Originales

El juego está programado para cargar dinámicamente las secuencias de imágenes PNG desde la ruta `data/original/` mediante la función `cargarOriginales()`. Aunque el ZIP ya incluye los recursos preinstalados, sigue estas instrucciones si necesitas instalarlos, reinstalarlos o verificarlos:

#### Opción A: Instalación Automática en Windows (Recomendada)

El proyecto incluye dos scripts dedicados para automatizar la copia y estructuración de los assets gráficos:

1. Ubícate dentro de la carpeta raíz `AgeOfWar1v1/`.

2. Haz doble clic sobre el archivo **`InstalarSpritesOriginales.bat`**.

3. Este archivo ejecutará internamente **`InstalarSpritesOriginales.ps1`** (PowerShell), el cual creará la jerarquía de directorios necesaria dentro de `data/original/` y ubicará cada sprite en su ruta correspondiente.

   * *Nota de permisos en Windows:* Si PowerShell bloquea la ejecución del script por políticas de seguridad, abre una terminal en la carpeta del proyecto y ejecuta:

     ```
     powershell -ExecutionPolicy Bypass -File .\InstalarSpritesOriginales.ps1
     
     ```

#### Opción B: Instalación Manual / Verificación de Estructura de Carpetas

Si utilizas **Linux**, **macOS** o deseas verificar manualmente que todos los sprites estén bien ubicados, asegúrate de que dentro de `AgeOfWar1v1/data/original/` exista exactamente esta estructura de carpetas y archivos:

```
data/original/
├── background.png                                      # Fondo principal del campo de batalla
├── bases/
│   ├── cave/                                           # Era 1: Cavernícola
│   │   ├── base/base.png
│   │   └── turret_1/
│   │       ├── cave_turret_1_attack0001.png
│   │       └── cave_turret_1_projectile.png
│   ├── knight/                                         # Era 2: Medieval
│   │   ├── base/base.png
│   │   └── turret_1/
│   │       ├── knight_turret_1_attack0001.png
│   │       └── knight_turret_1_projectile.png
│   └── future/                                         # Era 3: Futurista
│       ├── base/base.png
│       └── turret_1/
│           ├── future_turret_1_attack0001.png
│           └── future_turret_1_projectile.png
└── units/
    ├── cave/                                           # Unidades Era 1
    │   ├── melee/   (carpetas: attack/, idle/, walk/)
    │   ├── range/   (carpetas: idle/, idle_attack/, walk/)
    │   └── tank/    (carpetas: attack/, idle/, walk/)
    ├── knight/                                         # Unidades Era 2
    │   ├── melee/   (carpetas: attack/, idle/, walk/)
    │   ├── range/   (carpetas: idle/, idle_attack/, walk/)
    │   └── tank/    (carpetas: attack/, idle/, walk/)
    └── future/                                         # Unidades Era 3
        ├── melee/   (carpetas: attack/, idle/, walk/)
        ├── range/   (carpetas: idle/, idle_attack/, walk/)
        └── tank/    (carpetas: attack/, walk/)

```

#### ¿Cómo procesa el juego los Sprites al iniciar?

1. **Muestreo de fotogramas (`cargarSecuencia`):** Por cada acción (`walk`, `idle`, `attack` o `idle_attack`), el motor ordena alfabéticamente los archivos `.png` de la carpeta y toma hasta **10 fotogramas** distribuidos uniformemente.

2. **Normalización automática (`normalizarAnimaciones`):** El juego calcula la caja delimitadora real sin transparencia (`limitesAlfa`) de cada imagen para recortar bordes vacíos y escalar todas las animaciones de una misma unidad a una altura visual coherente, evitando saltos de tamaño entre caminar y atacar.

3. **Confirmación en consola:** Al ejecutar el sketch, verás en la consola inferior de Processing el mensaje:
   `[GRAFICOS] Sprites originales: XX animaciones cargadas`

4. **Modo de Respaldo (*Fallback*):** Si por algún motivo no se encuentra la carpeta `data/original/`, el juego no falla; automáticamente activa `generarDibujos()` y `generarFondo()` para renderizar gráficos vectoriales geométricos.

### 3. Cómo Iniciar una Partida 1v1 en LAN

El mismo ejecutable funciona tanto para el **Jugador 1 (Host)** como para el **Jugador 2 (Cliente)**:

1. **En la PC 1 (Host):** Abre `AgeOfWar1v1.pde` con Processing y presiona el botón **Run (▶)**. Al no detectar ningún servidor activo en la red tras 1.5 segundos, iniciará automáticamente en modo **Host** escuchando en el puerto TCP `12345`.

2. **En la PC 2 (Cliente):** Abre `AgeOfWar1v1.pde` con Processing y presiona **Run (▶)**. El cliente enviará un *broadcast* UDP (`HAY_SERVER?`) al puerto `8888`, detectará al Host y se conectará automáticamente.

3. **En el Lobby:**

   * El **Jugador 2** debe hacer clic en **"COMENZAR PARTIDA"** para avisar que está listo.

   * Una vez que ambos estén conectados y listos, el **Jugador 1 (Host)** hace clic en **"COMENZAR PARTIDA"** para iniciar la batalla.

## 🎮 Controles y Mecánicas

| Tecla / Acción | Función | 
| ----- | ----- | 
| **`1` / `2` / `3`** | Reclutar Unidad Cuerpo a Cuerpo (`1`), a Distancia (`2`) o Pesada/Tanque (`3`). | 
| **`Q` / `W`** | Construir Torreta defensiva en el Slot 1 (`Q`) o Slot 2 (`W`). | 
| **`Z` / `X`** | Vender Torreta del Slot 1 (`Z`) o Slot 2 (`X`) recuperando el 50% de su costo. | 
| **`E`** | Evolucionar a la siguiente Era (*Cavernícola* $\rightarrow$ *Medieval* $\rightarrow$ *Futurista*). | 
| **`S` / `Espacio` / `Clic en campo`** | Lanzar Habilidad Especial de la era actual sobre la zona enemiga (Cooldown: 60s). | 
| **`R`** | Solicitar revancha al finalizar la partida (en pantalla de Game Over). | 

## 🏗️ Arquitectura de Clases y Métodos

El código sigue un diseño orientado a objetos donde el **Servidor (Host)** simula la física, colisiones, economía y combate, sincronizando el estado con el **Cliente** mediante tramas de texto plano de 6 enteros (`emisor codigo d1 d2 d3 d4`).

### 1. `Jugador`

Representa el estado económico, tecnológico y de salud de la base de cada participante.

* **Atributos:** `id`, `oro`, `xp`, `era`, `hp`, `maxHp`, `cooldown`.

* **Métodos:**

  * `Jugador(int id)`: Inicializa los recursos iniciales (`ORO_INICIAL = 250`) y salud base (`500 HP`).

### 2. `Unidad` *(Clase Abstracta)*

Clase base polimórfica que gestiona el comportamiento, movimiento en carril, detección de enemigos y renderizado animado de todas las tropas.

* **Subclases:** `UnidadCuerpo`, `UnidadDistancia`, `UnidadPesada`.

* **Atributos:** `id`, `owner`, `era`, `tipo`, `hp`, `hpMax`, `danio`, `rango`, `velocidad`, `periodo`, `tiempoAtaque`, `ancho`, `alto`, `posicion`, `objetivo`, `vel`, `animAtaque`, `muerta`, `moviendo`, `enReserva`.

* **Métodos:**

  * `Unidad(int o, int t, int i, int e)`: Configura estadísticas según la matriz de era y tipo.

  * `actualizarServidor(float dt)`: Controla la IA de avance, evita superposición de tropas en el carril y ejecuta ataques si hay objetivos en rango.

  * `atacar(Unidad victima)`: Inflige daño cuerpo a cuerpo o instancia un `Proyectil` si el alcance es mayor a `90`.

  * `atacarBase()`: Ataca directamente la estructura enemiga cuando llega al frente de su base.

  * `dibujar()`: Selecciona el fotograma de animación correspondiente (`idle`, `walk`, `attack`), aplica espejo horizontal para el Jugador 2 y dibuja la barra de salud.

### 3. `Torreta`

Defensas estáticas montadas en los dos espacios superiores de cada base.

* **Atributos:** `owner`, `slot`, `tipo`, `posicion`, `cd`.

* **Métodos:**

  * `Torreta(int o, int s, int t)`: Posiciona la torreta en la coordenada correspondiente de la base izquierda o derecha.

  * `actualizarServidor(float dt)`: Busca el enemigo más cercano dentro de `RANGO_TORRE` y dispara automáticamente al cumplirse su enfriamiento.

  * `dibujar()`: Renderiza el sprite de la torreta según la era en la que fue construida.

### 4. `Proyectil`

Modela flechas, piedras, disparos láser y proyectiles de torretas en vuelo.

* **Atributos:** `owner`, `idAtacante`, `danio`, `objetivoID`, `posicion`, `velocidad`, `muerto`, `ttl`.

* **Métodos:**

  * `Proyectil(...)`: Inicializa posición de salida, vector de velocidad y daño.

  * `actualizarServidor(float dt)`: Desplaza el proyectil y evalúa colisiones mediante intersección de segmento contra caja (`segmentoContraCaja`) frente a unidades y bases enemigas.

  * `dibujar()`: Dibuja el proyectil en su posición actual.

### 5. `Particula`

Sistema de efectos visuales para impactos, explosiones y habilidades especiales.

* **Atributos:** `posicion`, `velocidad`, `vida`, `vidaInicial`, `col`.

* **Métodos:**

  * `actualizar(float dt)`: Aplica física simple con gravedad y reduce el tiempo de vida.

  * `dibujar()`: Renderiza partículas con desvanecimiento alfa progresivo.

### 6. `Mensaje`

Estructura encargada de encapsular los paquetes del protocolo de red TCP.

* **Atributos:** `emisor`, `codigo` (del `1` al `10`: `SPAWN_UNIT`, `UPDATE_POS`, `BASE_HP`, etc.), `d1`, `d2`, `d3`, `d4`.

* **Métodos:**

  * `Mensaje(int[] d)`: Construye el objeto a partir de los 6 enteros parseados por `interpretar(String linea)`.

## 🔧 Funciones Principales del Motor (Global)

* **Red y Descubrimiento:** `descubrirYConectar()`, `responderDescubrimiento()`, `recibirDatos()`, `interpretar()`, `consumirCola()`, `emitir()`, `vaciarEnvioHost()`.

* **Simulación y Combate (Autoritativo):** `simularServidor(float dt)`, `actualizarReplica(float dt)`, `avancePosible()`, `disparar()`, `herirUnidad()`, `herirBase()`, `segmentoContraCaja()`.

* **Gestión Gráfica y Sprites:** `cargarOriginales()`, `cargarSecuencia()`, `normalizarAnimaciones()`, `limitesAlfa()`, `recorteAlfa()`, `dibujarCampo()`, `dibujarHUD()`, `dibujarLobby()`.