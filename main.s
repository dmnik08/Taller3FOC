/*****Datos administrativos************************
 * Nombre del archivo: main.s
 * Tipo de archivo: Código fuente ensamblador AArch64
 * Proyecto: Filtros de imágenes PPM
 * Autor: Dóminick Viales Mora, Jahrell Gourzong Ortiz
 * Empresa: Instituto Tecnológico de Costa Rica
 *****Descripción**********************************
 * Procesador de imágenes PPM. Aplica filtros de inversión de color,
 * escala de grises, sal y pimienta, desenfoque por promedio y
 * separación de canales RGB.
 * Registros globales: x19 descriptor de archivo, x20 bytes leídos,
 * x26 tamaño del encabezado PPM, x27 bytes de píxeles de la imagen.
 *****Versión**************************************
 * 01 | 07/10/2026 18:00 | Dóminick Viales Mora, Jahrell Gourzong Ortiz
 *
 **************************************************/

/* Constantes globales */
.equ STDIN, 0                       // Descriptor de entrada estándar
.equ STDOUT, 1                      // Descriptor de salida estándar
.equ STDERR, 2                      // Descriptor de error estándar
.equ AT_FDCWD, -100                 // Directorio de trabajo actual (openat)
.equ SYS_READ, 63                   // Número de syscall read
.equ SYS_WRITE, 64                  // Número de syscall write
.equ SYS_OPENAT, 56                 // Número de syscall openat
.equ SYS_CLOSE, 57                  // Número de syscall close
.equ SYS_EXIT, 93                   // Número de syscall exit
.equ FLAGS_ESCRITURA, 0x241         // O_WRONLY | O_CREAT | O_TRUNC
.equ PERMISOS, 0644                 // Permisos del archivo de salida
.equ RUTA_SIZE, 256                 // Tamaño de los buffers de ruta
.equ BUFFER_SIZE, 2000000           // Tamaño de los buffers de imagen

.data
    MensajeBienvenida:  .ascii "\n PROCESADOR DE IMAGENES PPM \n\n"     // Título del programa
    .equ LEN_BIENVENIDA, . - MensajeBienvenida                          // Longitud del mensaje de bienvenida

    MensajeMenu:        .ascii "[1] Aplicar filtro de inversion de color.\n[2] Aplicar filtro de escala de grises.\n[3] Separacion de canales.\n[4] Desenfoque por  promedio.\n[5] Filtro sal y pimienta\n[0] Salir.\n"  // Menú principal
    .equ LEN_MENU, . - MensajeMenu                                      // Longitud del menú

    MensajeSolicitar:   .ascii "Introduzca la ubicacion relativa de la imagen:"  // Solicitud de la ruta de la imagen
    .equ LEN_SOLICITAR, . - MensajeSolicitar                            // Longitud de la solicitud

    Error01:            .ascii "Error:No se pudo abrir el archivo.\n\n" // Mensaje a desplegar ante error #01
    .equ LEN_ERROR01, . - Error01                                       // Longitud del error #01

    MensajeExitoAbrir:  .ascii "El archivo se abrio correctamente\n\n"  // Mensaje de éxito al abrir el archivo
    .equ LEN_EXITO_ABRIR, . - MensajeExitoAbrir                         // Longitud del mensaje de éxito

    Error02:            .ascii "Error: La opcion elegida es invalida!\n\n"  // Mensaje a desplegar ante error #02
    .equ LEN_ERROR02, . - Error02                                       // Longitud del error #02

    MensajeImagenLista: .ascii "Imagen Lista!!\n\n"                     // Mensaje de imagen procesada
    .equ LEN_IMAGEN_LISTA, . - MensajeImagenLista                       // Longitud del mensaje de imagen lista

    SufijoInverted:     .asciz "_inverted"      // Sufijo del archivo de salida de inversión
    SufijoGreyscale:    .asciz "_greyscale"     // Sufijo del archivo de salida de escala de grises
    SufijoSaltpeper:    .asciz "_saltpeper"     // Sufijo del archivo de salida de sal y pimienta
    SufijoCanalRojo:    .asciz "_red"           // Sufijo del archivo de salida del canal rojo
    SufijoCanalVerde:   .asciz "_green"         // Sufijo del archivo de salida del canal verde
    SufijoCanalAzul:    .asciz "_blue"          // Sufijo del archivo de salida del canal azul
    SufijoBlur:         .asciz "_blur"          // Sufijo del archivo de salida del desenfoque
    ExtPpm:             .asciz ".ppm"           // Extensión del archivo de salida

.bss
    RutaArchivo:            .space RUTA_SIZE        // Ruta de la imagen de entrada
    RutaSalida:             .space RUTA_SIZE        // Ruta de la imagen de salida
    SeleccionUsuario:       .space 4                // Opción elegida por el usuario
    BufferImagenOriginal:   .space BUFFER_SIZE      // Imagen original sin modificar
    BufferImagenFiltro:     .space BUFFER_SIZE      // Imagen sobre la que se aplica el filtro
    BufferCanalRojo:        .space BUFFER_SIZE      // Imagen del canal rojo
    BufferCanalVerde:       .space BUFFER_SIZE      // Imagen del canal verde
    BufferCanalAzul:        .space BUFFER_SIZE      // Imagen del canal azul

.text
.global _start

/*****Nombre***************************************
 * f01GenerarNombreSalida:
 *****Descripción**********************************
 * Genera el nombre del archivo de salida concatenando la ruta de
 * entrada (sin extensión), el sufijo del filtro y la extensión .ppm.
 *****Retorno**************************************
 * Ninguno. El resultado se escribe en RutaSalida.
 *****Entradas*************************************
 * x10: Puntero al string del sufijo a agregar al nombre de salida
 *****Errores**************************************
 * Ninguno
 **************************************************/
f01GenerarNombreSalida:
    ldr x0, =RutaArchivo            // Puntero de lectura de la ruta de entrada
    ldr x1, =RutaSalida             // Puntero de escritura de la ruta de salida

    // Ciclo: copia la ruta de entrada hasta el nulo o el punto de la extensión
f01for01:
    ldrb w2, [x0], 1                // Carácter actual de la ruta
    cmp w2, 0
    beq f01finfor01
    cmp w2, '.'
    beq f01finfor01
    strb w2, [x1], 1
    b f01for01

f01finfor01:
    mov x2, x10                     // Puntero de lectura del sufijo

    // Ciclo: agrega el sufijo del filtro a la ruta de salida
f01for02:
    ldrb w3, [x2], 1                // Carácter actual del sufijo
    cmp w3, 0
    beq f01finfor02
    strb w3, [x1], 1
    b f01for02

f01finfor02:
    ldr x2, =ExtPpm                 // Puntero de lectura de la extensión

    // Ciclo: agrega la extensión .ppm y el nulo final
f01for03:
    ldrb w3, [x2], 1                // Carácter actual de la extensión
    strb w3, [x1], 1
    cmp w3, 0
    bne f01for03
    ret

/*****Nombre***************************************
 * f02CopiarABuffersCanal:
 *****Descripción**********************************
 * Copia x2 bytes desde el buffer origen (x0) al buffer destino (x1).
 * Usada para duplicar la imagen original en los buffers de canal.
 *****Retorno**************************************
 * Ninguno.
 *****Entradas*************************************
 * x0: Puntero al buffer de origen
 * x1: Puntero al buffer de destino
 * x2: Cantidad de bytes a copiar
 *****Errores**************************************
 * Ninguno
 **************************************************/
f02CopiarABuffersCanal:
    // Ciclo: copia byte a byte hasta agotar el contador
f02for01:
    cbz x2, f02finfor01             // x2: Cantidad de bytes restantes (entrada)
    ldrb w3, [x0], 1                // x0: Buffer de origen (entrada)
    strb w3, [x1], 1                // x1: Buffer de destino (entrada)
    sub x2, x2, 1
    b f02for01

f02finfor01:
    ret

/*****Nombre***************************************
 * f03MostrarBienvenida:
 *****Descripción**********************************
 * Punto de entrada del programa. Imprime el título y continúa
 * con la solicitud de la ruta de la imagen.
 *****Retorno**************************************
 * Ninguno. Continúa en f04SolicitarRuta.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * Ninguno
 **************************************************/
_start:
f03MostrarBienvenida:
    mov x0, STDOUT                  // Descriptor de salida estándar
    ldr x1, =MensajeBienvenida      // Dirección del mensaje a imprimir
    ldr x2, =LEN_BIENVENIDA         // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0
    b f04SolicitarRuta

/*****Nombre***************************************
 * f04SolicitarRuta:
 *****Descripción**********************************
 * Solicita al usuario la ruta de la imagen, la lee desde la entrada
 * estándar y reemplaza el salto de línea final por un nulo.
 *****Retorno**************************************
 * Ninguno. La ruta queda en RutaArchivo. Continúa en f05AbrirArchivo.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * Ninguno
 **************************************************/
f04SolicitarRuta:
    mov x0, STDOUT                  // Descriptor de salida estándar
    ldr x1, =MensajeSolicitar       // Dirección del mensaje a imprimir
    ldr x2, =LEN_SOLICITAR          // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0

    mov x0, STDIN                   // Descriptor de entrada estándar
    ldr x1, =RutaArchivo            // Buffer donde se guarda la ruta
    mov x2, RUTA_SIZE - 1           // Máximo de caracteres a leer
    mov x8, SYS_READ                // Syscall read
    svc 0

    sub x0, x0, 1                   // Posición del salto de línea leído
    ldr x1, =RutaArchivo            // Dirección base de la ruta
    strb wzr, [x1, x0]              // Reemplaza el salto de línea por nulo

/*****Nombre***************************************
 * f05AbrirArchivo:
 *****Descripción**********************************
 * Abre en modo lectura el archivo indicado en RutaArchivo.
 *****Retorno**************************************
 * x19: Descriptor del archivo abierto
 *****Entradas*************************************
 * Ninguna. Usa la ruta almacenada en RutaArchivo.
 *****Errores**************************************
 * 01: No se pudo abrir el archivo
 **************************************************/
f05AbrirArchivo:
    mov x0, AT_FDCWD                // Directorio base: el actual
    ldr x1, =RutaArchivo            // Ruta del archivo a abrir
    mov x2, 0                       // Flags: solo lectura
    mov x8, SYS_OPENAT              // Syscall openat
    svc 0

    cmp x0, 0
    blt f25ErrorRuta
    mov x19, x0                     // Descriptor del archivo de entrada

/*****Nombre***************************************
 * f06LeerArchivo:
 *****Descripción**********************************
 * Lee el archivo abierto en el buffer de imagen original, lo cierra
 * e informa al usuario que se abrió correctamente.
 *****Retorno**************************************
 * x20: Cantidad de bytes leídos
 *****Entradas*************************************
 * x19: Descriptor del archivo abierto
 *****Errores**************************************
 * 01: No se pudo leer el archivo
 **************************************************/
f06LeerArchivo:
    mov x0, x19                     // Descriptor del archivo a leer
    ldr x1, =BufferImagenOriginal   // Buffer destino de la lectura
    ldr x2, =BUFFER_SIZE            // Máximo de bytes a leer
    mov x8, SYS_READ                // Syscall read
    svc 0

    cmp x0, 0
    ble f25ErrorRuta
    mov x20, x0                     // Cantidad de bytes leídos

    mov x0, x19                     // Descriptor del archivo a cerrar
    mov x8, SYS_CLOSE               // Syscall close
    svc 0

    mov x0, STDOUT                  // Descriptor de salida estándar
    ldr x1, =MensajeExitoAbrir      // Dirección del mensaje a imprimir
    ldr x2, =LEN_EXITO_ABRIR        // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0

    b f07CopiarImagen

/*****Nombre***************************************
 * f07CopiarImagen:
 *****Descripción**********************************
 * Copia la imagen original al buffer sobre el que se aplicarán
 * los filtros.
 *****Retorno**************************************
 * Ninguno. Continúa en f08BuscarInicioPixeles.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 *****Errores**************************************
 * Ninguno
 **************************************************/
f07CopiarImagen:
    ldr x0, =BufferImagenOriginal   // Puntero de origen
    ldr x1, =BufferImagenFiltro     // Puntero de destino
    mov x2, x20                     // Contador de bytes restantes

    // Ciclo: copia byte a byte la imagen original
f07for01:
    cbz x2, f07finfor01
    ldrb w3, [x0], 1                // Byte actual de la imagen
    strb w3, [x1], 1
    sub x2, x2, 1
    b f07for01

f07finfor01:
    b f08BuscarInicioPixeles

/*****Nombre***************************************
 * f08BuscarInicioPixeles:
 *****Descripción**********************************
 * Recorre el encabezado PPM (tres saltos de línea) para calcular
 * el tamaño del encabezado y la cantidad de bytes de píxeles.
 *****Retorno**************************************
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 *****Errores**************************************
 * Ninguno
 **************************************************/
f08BuscarInicioPixeles:
    ldr x25, =BufferImagenFiltro    // Puntero de recorrido del encabezado
    mov x21, 0                      // Contador de saltos de línea encontrados

    // Ciclo: avanza hasta encontrar el tercer salto de línea
f08for01:
    ldrb w0, [x25], 1               // Carácter actual del encabezado
    cmp w0, 10
    bne f08for01
    add x21, x21, 1
    cmp x21, 3
    blt f08for01

    ldr x0, =BufferImagenFiltro     // Dirección base de la imagen
    sub x26, x25, x0                // Tamaño del encabezado
    sub x27, x20, x26               // Bytes de píxeles
    b f09MostrarMenu

/*****Nombre***************************************
 * f09MostrarMenu:
 *****Descripción**********************************
 * Imprime el menú principal.
 *****Retorno**************************************
 * Ninguno. Continúa en f10ProcesarSeleccion.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * Ninguno
 **************************************************/
f09MostrarMenu:
    mov x0, STDOUT                  // Descriptor de salida estándar
    ldr x1, =MensajeMenu            // Dirección del mensaje a imprimir
    ldr x2, =LEN_MENU               // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0

/*****Nombre***************************************
 * f10ProcesarSeleccion:
 *****Descripción**********************************
 * Lee la opción del usuario y salta a la función del filtro
 * correspondiente.
 *****Retorno**************************************
 * Ninguno. Continúa en la función de la opción elegida.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * 02: La opción elegida es inválida
 **************************************************/
f10ProcesarSeleccion:
    mov x0, STDIN                   // Descriptor de entrada estándar
    ldr x1, =SeleccionUsuario       // Buffer donde se guarda la opción
    mov x2, 2                       // Cantidad de caracteres a leer
    mov x8, SYS_READ                // Syscall read
    svc 0

    ldrb w0, [x1]                   // Carácter de la opción elegida
    cmp w0, '1'
    beq f11FiltroInversion

    cmp w0, '2'
    beq f12FiltroEscalaGrises

    cmp w0, '3'
    beq f16SepararCanalRojo

    cmp w0, '4'
    beq f14FiltroDesenfoque

    cmp w0, '5'
    beq f13FiltroSalPimienta

    cmp w0, '0'
    beq f27Salir

    b f26ErrorEleccion

/*****Nombre***************************************
 * f11FiltroInversion:
 *****Descripción**********************************
 * Invierte el color de cada byte de píxel (XOR con 0xFF).
 *****Retorno**************************************
 * Ninguno. Continúa en f22EscribirArchivoInversion.
 *****Entradas*************************************
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * Ninguno
 **************************************************/
f11FiltroInversion:
    ldr x10, =SufijoInverted        // Sufijo del archivo de salida
    bl f01GenerarNombreSalida

    ldr x0, =BufferImagenFiltro     // Dirección base de la imagen
    add x0, x0, x26                 // Puntero al primer píxel
    mov x2, x27                     // Contador de bytes restantes

    // Ciclo: invierte cada byte de píxel
f11for01:
    cbz x2, f11finfor01
    ldrb w3, [x0]                   // Valor del byte actual
    eor w3, w3, #0xFF
    strb w3, [x0], 1
    sub x2, x2, 1
    b f11for01

f11finfor01:
    b f22EscribirArchivoInversion

/*****Nombre***************************************
 * f12FiltroEscalaGrises:
 *****Descripción**********************************
 * Reemplaza cada píxel por el promedio de sus componentes R, G y B.
 *****Retorno**************************************
 * Ninguno. Continúa en f15FinalizarFiltro.
 *****Entradas*************************************
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * Ninguno
 **************************************************/
f12FiltroEscalaGrises:
    ldr x10, =SufijoGreyscale       // Sufijo del archivo de salida
    bl f01GenerarNombreSalida

    ldr x0, =BufferImagenFiltro     // Dirección base de la imagen
    add x0, x0, x26                 // Puntero al píxel actual
    mov x2, x27                     // Contador de bytes restantes

    // Ciclo: procesa un píxel (3 bytes) por iteración
f12for01:
    cmp x2, 2
    ble f15FinalizarFiltro

    ldrb w3, [x0]                   // Componente rojo
    ldrb w4, [x0, 1]                // Componente verde
    ldrb w5, [x0, 2]                // Componente azul

    add w6, w3, w4                  // Suma de componentes
    add w6, w6, w5
    mov w7, 3                       // Divisor del promedio
    udiv w6, w6, w7                 // Promedio (nivel de gris)

    strb w6, [x0]
    strb w6, [x0, 1]
    strb w6, [x0, 2]

    add x0, x0, 3
    sub x2, x2, 3
    b f12for01

/*****Nombre***************************************
 * f13FiltroSalPimienta:
 *****Descripción**********************************
 * Reemplaza aleatoriamente píxeles por negro o blanco usando un
 * generador congruencial lineal inicializado con el contador de tiempo.
 *****Retorno**************************************
 * Ninguno. Continúa en f15FinalizarFiltro.
 *****Entradas*************************************
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * Ninguno
 **************************************************/
f13FiltroSalPimienta:
    ldr x10, =SufijoSaltpeper       // Sufijo del archivo de salida
    bl f01GenerarNombreSalida

    ldr x0, =BufferImagenFiltro     // Dirección base de la imagen
    add x0, x0, x26                 // Puntero al píxel actual
    mov x2, x27                     // Contador de bytes restantes

    mrs x9, cntvct_el0              // Estado del generador (semilla)
    mov x13, #2531                  // Incremento del generador (parte base)
    lsl x13, x13, #10
    add x13, x13, #35               // Incremento del generador
    mov x11, #0x6c07                // Multiplicador del generador (parte baja)
    movk x11, #0x343f, lsl 16       // Multiplicador del generador (parte alta)

    // Ciclo: decide por píxel si se altera y con qué color
f13for01:
    cmp x2, 2
    ble f15FinalizarFiltro

    mul x9, x9, x11
    add x9, x9, x13
    lsr x12, x9, #30                // Bits aleatorios: ¿se altera el píxel?
    and x12, x12, #3
    cmp x12, 0
    bne f13sigpixel

    mul x9, x9, x11
    add x9, x9, x13
    lsr x12, x9, #31                // Bit aleatorio: negro (1) o blanco (0)
    and x12, x12, #1
    cmp x12, 0
    beq f13pixelblanco

f13pixelnegro:
    strb wzr, [x0]
    strb wzr, [x0, 1]
    strb wzr, [x0, 2]
    b f13sigpixel

f13pixelblanco:
    mov w13, #255                   // Valor blanco
    strb w13, [x0]
    strb w13, [x0, 1]
    strb w13, [x0, 2]

f13sigpixel:
    add x0, x0, 3
    sub x2, x2, 3
    b f13for01

/*****Nombre***************************************
 * f14FiltroDesenfoque:
 *****Descripción**********************************
 * Reemplaza cada byte interno de la imagen por el promedio de los
 * 9 bytes vecinos del mismo canal, leídos de la imagen original.
 *****Retorno**************************************
 * Ninguno. Continúa en f15FinalizarFiltro.
 *****Entradas*************************************
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * Ninguno
 **************************************************/
f14FiltroDesenfoque:
    ldr x10, =SufijoBlur            // Sufijo del archivo de salida
    bl f01GenerarNombreSalida

    ldr x0, =BufferImagenFiltro     // Dirección base de la imagen
    add x2, x0, 3                   // Puntero al ancho (después de "P6\n")

    mov x14, 0                      // Ancho de la imagen en píxeles

    // Ciclo: convierte el ancho de texto decimal a número
f14forancho01:
    ldrb w4, [x2], 1                // Carácter actual del ancho
    cmp w4, ' '
    beq f14finforancho01
    cmp w4, 10
    beq f14finforancho01
    sub w4, w4, '0'
    mov x5, 10                      // Base decimal
    mul x14, x14, x5
    add x14, x14, x4
    b f14forancho01

f14finforancho01:
    mov x15, 3                      // Bytes por píxel
    mul x15, x14, x15               // Bytes por fila

    udiv x16, x27, x15              // Alto de la imagen en píxeles

    ldr x1, =BufferImagenOriginal   // Dirección base de la imagen original
    add x1, x1, x26                 // Puntero a los píxeles originales
    ldr x0, =BufferImagenFiltro     // Dirección base de la imagen filtrada
    add x0, x0, x26                 // Puntero a los píxeles filtrados

    cmp x14, 3
    blt f15FinalizarFiltro
    cmp x16, 3
    blt f15FinalizarFiltro

    mov x17, 1                      // Fila actual y

    // Ciclo: recorre las filas internas de la imagen
f14fory01:
    sub x4, x16, 1                  // Límite superior de filas
    cmp x17, x4
    beq f15FinalizarFiltro

    mov x18, 1                      // Columna actual x

    // Ciclo: recorre las columnas internas de la fila
f14forx01:
    sub x4, x14, 1                  // Límite superior de columnas
    cmp x18, x4
    beq f14sigy01

    mul x12, x17, x15               // Desplazamiento de la fila
    mov x4, 3                       // Bytes por píxel
    mul x5, x18, x4
    add x12, x12, x5                // Desplazamiento del píxel

    mov x13, 0                      // Canal actual (0=R, 1=G, 2=B)

    // Ciclo: promedia los 9 vecinos de cada canal del píxel
f14forcanal01:
    cmp x13, 3
    beq f14sigx01

    add x22, x12, x13               // Desplazamiento del byte actual

    mov x23, 0                      // Acumulador de la suma de vecinos

    // Fila superior
    sub x4, x22, x15                // Desplazamiento del vecino superior izquierdo
    sub x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    add x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    add x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    // Fila central
    sub x4, x22, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    add x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    add x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    // Fila inferior
    add x4, x22, x15
    sub x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    add x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    add x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    mov x4, 9                       // Divisor del promedio
    udiv x23, x23, x4

    strb w23, [x0, x22]

    add x13, x13, 1
    b f14forcanal01

f14sigx01:
    add x18, x18, 1
    b f14forx01

f14sigy01:
    add x17, x17, 1
    b f14fory01

/*****Nombre***************************************
 * f15FinalizarFiltro:
 *****Descripción**********************************
 * Punto común de salida de los filtros que usan BufferImagenFiltro.
 *****Retorno**************************************
 * Ninguno. Continúa en f23EscribirArchivo.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * Ninguno
 **************************************************/
f15FinalizarFiltro:
    b f23EscribirArchivo

/*****Nombre***************************************
 * f16SepararCanalRojo:
 *****Descripción**********************************
 * Genera la imagen del canal rojo (verde y azul en cero).
 *****Retorno**************************************
 * Ninguno. Continúa en f17EscribirCanalRojo.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * Ninguno
 **************************************************/
f16SepararCanalRojo:
    ldr x0, =BufferImagenOriginal   // Puntero de origen
    ldr x1, =BufferCanalRojo        // Puntero de destino
    mov x2, x20                     // Cantidad de bytes a copiar
    bl f02CopiarABuffersCanal

    ldr x10, =SufijoCanalRojo       // Sufijo del archivo de salida
    bl f01GenerarNombreSalida

    ldr x0, =BufferCanalRojo        // Dirección base del canal rojo
    add x0, x0, x26                 // Puntero al píxel actual
    mov x2, x27                     // Contador de bytes restantes

    // Ciclo: conserva el rojo y borra verde y azul de cada píxel
f16for01:
    cbz x2, f17EscribirCanalRojo
    ldrb w3, [x0]                   // Componente rojo
    strb w3, [x0], 1

    mov w3, 0                       // Valor cero para verde y azul
    strb w3, [x0], 1
    strb w3, [x0], 1

    sub x2, x2, 3
    b f16for01

/*****Nombre***************************************
 * f17EscribirCanalRojo:
 *****Descripción**********************************
 * Escribe el archivo del canal rojo y continúa con el canal verde.
 *****Retorno**************************************
 * Ninguno. Continúa en f18SepararCanalVerde.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 *****Errores**************************************
 * Ninguno
 **************************************************/
f17EscribirCanalRojo:
    mov x0, AT_FDCWD                // Directorio base: el actual
    ldr x1, =RutaSalida             // Ruta del archivo de salida
    mov x2, FLAGS_ESCRITURA         // Flags de apertura para escritura
    mov x3, PERMISOS                // Permisos del archivo creado
    mov x8, SYS_OPENAT              // Syscall openat
    svc 0
    mov x19, x0                     // Descriptor del archivo de salida
    mov x0, x19                     // Descriptor donde se escribe
    ldr x1, =BufferCanalRojo        // Buffer a escribir
    mov x2, x20                     // Cantidad de bytes a escribir
    mov x8, SYS_WRITE               // Syscall write
    svc 0
    mov x0, x19                     // Descriptor a cerrar
    mov x8, SYS_CLOSE               // Syscall close
    svc 0
    b f18SepararCanalVerde

/*****Nombre***************************************
 * f18SepararCanalVerde:
 *****Descripción**********************************
 * Genera la imagen del canal verde (rojo y azul en cero).
 *****Retorno**************************************
 * Ninguno. Continúa en f19EscribirCanalVerde.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * Ninguno
 **************************************************/
f18SepararCanalVerde:
    ldr x0, =BufferImagenOriginal   // Puntero de origen
    ldr x1, =BufferCanalVerde       // Puntero de destino
    mov x2, x20                     // Cantidad de bytes a copiar
    bl f02CopiarABuffersCanal

    ldr x10, =SufijoCanalVerde      // Sufijo del archivo de salida
    bl f01GenerarNombreSalida

    ldr x0, =BufferCanalVerde       // Dirección base del canal verde
    add x0, x0, x26                 // Puntero al píxel actual
    mov x2, x27                     // Contador de bytes restantes

    // Ciclo: conserva el verde y borra rojo y azul de cada píxel
f18for01:
    cbz x2, f19EscribirCanalVerde
    mov w3, 0                       // Valor cero para rojo
    strb w3, [x0], 1

    ldrb w3, [x0]                   // Componente verde
    strb w3, [x0], 1

    mov w3, 0                       // Valor cero para azul
    strb w3, [x0], 1

    sub x2, x2, 3
    b f18for01

/*****Nombre***************************************
 * f19EscribirCanalVerde:
 *****Descripción**********************************
 * Escribe el archivo del canal verde y continúa con el canal azul.
 *****Retorno**************************************
 * Ninguno. Continúa en f20SepararCanalAzul.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 *****Errores**************************************
 * Ninguno
 **************************************************/
f19EscribirCanalVerde:
    mov x0, AT_FDCWD                // Directorio base: el actual
    ldr x1, =RutaSalida             // Ruta del archivo de salida
    mov x2, FLAGS_ESCRITURA         // Flags de apertura para escritura
    mov x3, PERMISOS                // Permisos del archivo creado
    mov x8, SYS_OPENAT              // Syscall openat
    svc 0
    mov x19, x0                     // Descriptor del archivo de salida
    mov x0, x19                     // Descriptor donde se escribe
    ldr x1, =BufferCanalVerde       // Buffer a escribir
    mov x2, x20                     // Cantidad de bytes a escribir
    mov x8, SYS_WRITE               // Syscall write
    svc 0
    mov x0, x19                     // Descriptor a cerrar
    mov x8, SYS_CLOSE               // Syscall close
    svc 0
    b f20SepararCanalAzul

/*****Nombre***************************************
 * f20SepararCanalAzul:
 *****Descripción**********************************
 * Genera la imagen del canal azul (rojo y verde en cero).
 *****Retorno**************************************
 * Ninguno. Continúa en f21EscribirCanalAzul.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * Ninguno
 **************************************************/
f20SepararCanalAzul:
    ldr x0, =BufferImagenOriginal   // Puntero de origen
    ldr x1, =BufferCanalAzul        // Puntero de destino
    mov x2, x20                     // Cantidad de bytes a copiar
    bl f02CopiarABuffersCanal

    ldr x10, =SufijoCanalAzul       // Sufijo del archivo de salida
    bl f01GenerarNombreSalida

    ldr x0, =BufferCanalAzul        // Dirección base del canal azul
    add x0, x0, x26                 // Puntero al píxel actual
    mov x2, x27                     // Contador de bytes restantes

    // Ciclo: conserva el azul y borra rojo y verde de cada píxel
f20for01:
    cbz x2, f21EscribirCanalAzul
    mov w3, 0                       // Valor cero para rojo
    strb w3, [x0], 1

    mov w3, 0                       // Valor cero para verde
    strb w3, [x0], 1

    ldrb w3, [x0]                   // Componente azul
    strb w3, [x0], 1

    sub x2, x2, 3
    b f20for01

/*****Nombre***************************************
 * f21EscribirCanalAzul:
 *****Descripción**********************************
 * Escribe el archivo del canal azul y muestra el mensaje final.
 *****Retorno**************************************
 * Ninguno. Continúa en f24ImprimirImagenLista.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 *****Errores**************************************
 * Ninguno
 **************************************************/
f21EscribirCanalAzul:
    mov x0, AT_FDCWD                // Directorio base: el actual
    ldr x1, =RutaSalida             // Ruta del archivo de salida
    mov x2, FLAGS_ESCRITURA         // Flags de apertura para escritura
    mov x3, PERMISOS                // Permisos del archivo creado
    mov x8, SYS_OPENAT              // Syscall openat
    svc 0
    mov x19, x0                     // Descriptor del archivo de salida
    mov x0, x19                     // Descriptor donde se escribe
    ldr x1, =BufferCanalAzul        // Buffer a escribir
    mov x2, x20                     // Cantidad de bytes a escribir
    mov x8, SYS_WRITE               // Syscall write
    svc 0
    mov x0, x19                     // Descriptor a cerrar
    mov x8, SYS_CLOSE               // Syscall close
    svc 0
    b f24ImprimirImagenLista

/*****Nombre***************************************
 * f22EscribirArchivoInversion:
 *****Descripción**********************************
 * Escribe la imagen invertida y restaura el buffer de trabajo con
 * la imagen original, ya que el filtro de inversión se aplica
 * sobre BufferImagenFiltro.
 *****Retorno**************************************
 * Ninguno. Continúa en f24ImprimirImagenLista.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 *****Errores**************************************
 * Ninguno
 **************************************************/
f22EscribirArchivoInversion:
    mov x0, AT_FDCWD                // Directorio base: el actual
    ldr x1, =RutaSalida             // Ruta del archivo de salida
    mov x2, FLAGS_ESCRITURA         // Flags de apertura para escritura
    mov x3, PERMISOS                // Permisos del archivo creado
    mov x8, SYS_OPENAT              // Syscall openat
    svc 0

    mov x19, x0                     // Descriptor del archivo de salida
    mov x0, x19                     // Descriptor donde se escribe
    ldr x1, =BufferImagenFiltro     // Buffer a escribir
    mov x2, x20                     // Cantidad de bytes a escribir
    mov x8, SYS_WRITE               // Syscall write
    svc 0

    mov x0, x19                     // Descriptor a cerrar
    mov x8, SYS_CLOSE               // Syscall close
    svc 0

    ldr x0, =BufferImagenOriginal   // Puntero de origen
    ldr x1, =BufferImagenFiltro     // Puntero de destino
    mov x2, x20                     // Cantidad de bytes a copiar
    bl f02CopiarABuffersCanal
    b f24ImprimirImagenLista

/*****Nombre***************************************
 * f23EscribirArchivo:
 *****Descripción**********************************
 * Escribe en el archivo de salida el contenido de BufferImagenFiltro.
 *****Retorno**************************************
 * Ninguno. Continúa en f24ImprimirImagenLista.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 *****Errores**************************************
 * Ninguno
 **************************************************/
f23EscribirArchivo:
    mov x0, AT_FDCWD                // Directorio base: el actual
    ldr x1, =RutaSalida             // Ruta del archivo de salida
    mov x2, FLAGS_ESCRITURA         // Flags de apertura para escritura
    mov x3, PERMISOS                // Permisos del archivo creado
    mov x8, SYS_OPENAT              // Syscall openat
    svc 0

    mov x19, x0                     // Descriptor del archivo de salida
    mov x0, x19                     // Descriptor donde se escribe
    ldr x1, =BufferImagenFiltro     // Buffer a escribir
    mov x2, x20                     // Cantidad de bytes a escribir
    mov x8, SYS_WRITE               // Syscall write
    svc 0

    mov x0, x19                     // Descriptor a cerrar
    mov x8, SYS_CLOSE               // Syscall close
    svc 0
    b f24ImprimirImagenLista

/*****Nombre***************************************
 * f24ImprimirImagenLista:
 *****Descripción**********************************
 * Informa que la imagen fue procesada y regresa al menú.
 *****Retorno**************************************
 * Ninguno. Continúa en f09MostrarMenu.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * Ninguno
 **************************************************/
f24ImprimirImagenLista:
    mov x0, STDOUT                  // Descriptor de salida estándar
    ldr x1, =MensajeImagenLista     // Dirección del mensaje a imprimir
    ldr x2, =LEN_IMAGEN_LISTA       // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0

    b f09MostrarMenu

/*****Nombre***************************************
 * f25ErrorRuta:
 *****Descripción**********************************
 * Muestra el error de apertura/lectura de archivo y vuelve a
 * solicitar la ruta.
 *****Retorno**************************************
 * Ninguno. Continúa en f04SolicitarRuta.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * 01: No se pudo abrir el archivo
 **************************************************/
f25ErrorRuta:
    mov x0, STDERR                  // Descriptor de error estándar
    ldr x1, =Error01                // Mensaje del error #01
    ldr x2, =LEN_ERROR01            // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0
    b f04SolicitarRuta

/*****Nombre***************************************
 * f26ErrorEleccion:
 *****Descripción**********************************
 * Muestra el error de opción inválida y regresa al menú.
 *****Retorno**************************************
 * Ninguno. Continúa en f09MostrarMenu.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * 02: La opción elegida es inválida
 **************************************************/
f26ErrorEleccion:
    mov x0, STDERR                  // Descriptor de error estándar
    ldr x1, =Error02                // Mensaje del error #02
    ldr x2, =LEN_ERROR02            // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0
    b f09MostrarMenu

/*****Nombre***************************************
 * f27Salir:
 *****Descripción**********************************
 * Termina el programa con código de salida 0.
 *****Retorno**************************************
 * Ninguno. El programa finaliza.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * Ninguno
 **************************************************/
f27Salir:
    mov x0, 0                       // Código de salida
    mov x8, SYS_EXIT                // Syscall exit
    svc 0
