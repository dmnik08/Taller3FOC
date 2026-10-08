/*****Datos administrativos************************
 * Nombre del archivo: main.s
 * Tipo de archivo: Código fuente ensamblador AArch64
 * Proyecto: Filtros de imágenes PPM
 * Autor: Dóminick Viales Mora, Jahrell Gourzong Ortiz
 * Empresa: Instituto Tecnológico de Costa Rica
 *****Descripción**********************************
 * Procesador de imágenes PPM (formato P6, maxval 255). Aplica filtros
 * de inversión de color, escala de grises, sal y pimienta, desenfoque
 * por promedio y separación de canales RGB. Para cada filtro elegido
 * en el menú se solicita la ubicación relativa de la imagen y se
 * guarda el resultado junto a la original, sin modificarla.
 * Registros globales: x19 descriptor de archivo, x20 bytes leídos,
 * x21 ancho, x24 alto, x26 tamaño del encabezado, x27 bytes de
 * píxeles (ancho * alto * 3), x28 opción elegida en el menú.
 *****Versión**************************************
 * 01 | 07/10/2026 18:00 | Dóminick Viales Mora, Jahrell Gourzong Ortiz
 * 02 | 07/10/2026 | Dóminick Viales Mora, Jahrell Gourzong Ortiz (corrección de errores)
 * 03 | 07/10/2026 | Dóminick Viales Mora, Jahrell Gourzong Ortiz (menú antes de la ruta y validaciones)
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
.equ RUTA_SIZE, 256                 // Tamaño del buffer de la ruta de entrada
.equ SELECCION_SIZE, 8              // Tamaño del buffer de la opción del menú
.equ BUFFER_SIZE, 2000000           // Tamaño de los buffers de imagen
.equ MAX_DIMENSION, 65535           // Mayor valor aceptado para ancho, alto y maxval

.data
    MensajeBienvenida:  .ascii "\n PROCESADOR DE IMAGENES PPM \n\n"     // Título del programa
    .equ LEN_BIENVENIDA, . - MensajeBienvenida                          // Longitud del mensaje de bienvenida

    MensajeMenu:        .ascii "[1] Aplicar filtro de inversion de color.\n[2] Aplicar filtro de escala de grises.\n[3] Separacion de canales.\n[4] Desenfoque por  promedio.\n[5] Filtro sal y pimienta\n[0] Salir.\n"  // Menú principal
    .equ LEN_MENU, . - MensajeMenu                                      // Longitud del menú

    MensajeSolicitar:   .ascii "Introduzca la ubicacion relativa de la imagen:"  // Solicitud de la ruta de la imagen
    .equ LEN_SOLICITAR, . - MensajeSolicitar                            // Longitud de la solicitud

    Error01:            .ascii "Error: No se pudo abrir o leer el archivo.\n\n"  // Mensaje a desplegar ante error #01
    .equ LEN_ERROR01, . - Error01                                       // Longitud del error #01

    Error02:            .ascii "Error: La opcion elegida es invalida! Escriba un solo numero del 0 al 5.\n\n"  // Mensaje a desplegar ante error #02
    .equ LEN_ERROR02, . - Error02                                       // Longitud del error #02

    Error03:            .ascii "Error: La ruta esta vacia o es demasiado larga.\n\n"  // Mensaje a desplegar ante error #03
    .equ LEN_ERROR03, . - Error03                                       // Longitud del error #03

    Error04:            .ascii "Error: El archivo no es una imagen PPM valida (se requiere P6 con maxval 255).\n\n"  // Mensaje a desplegar ante error #04
    .equ LEN_ERROR04, . - Error04                                       // Longitud del error #04

    Error05:            .ascii "Error: El archivo supera el tamano maximo permitido (2000000 bytes).\n\n"  // Mensaje a desplegar ante error #05
    .equ LEN_ERROR05, . - Error05                                       // Longitud del error #05

    Error06:            .ascii "Error: No se pudo crear o escribir el archivo de salida.\n\n"  // Mensaje a desplegar ante error #06
    .equ LEN_ERROR06, . - Error06                                       // Longitud del error #06

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
    RutaSalida:             .space RUTA_SIZE + 32   // Ruta de salida (con sufijo y extensión)
    SeleccionUsuario:       .space SELECCION_SIZE   // Opción elegida por el usuario
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
 * Genera el nombre del archivo de salida a partir de la ruta de
 * entrada: reemplaza la extensión (último punto del nombre de archivo)
 * por el sufijo del filtro seguido de la extensión .ppm.
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
    mov x4, 0                       // Posición del último punto de la extensión (0 = sin extensión)

    // Ciclo: copia la ruta completa recordando el último punto del nombre de archivo
f01for01:
    ldrb w2, [x0], 1                // Carácter actual de la ruta
    cmp w2, 0
    beq f01finfor01
    cmp w2, '/'
    bne f01sinbarra01
    mov x4, 0                       // Un punto antes de la barra pertenece a un directorio
f01sinbarra01:
    cmp w2, '.'
    bne f01sinpunto01
    mov x4, x1                      // Posición del punto dentro de RutaSalida
f01sinpunto01:
    strb w2, [x1], 1
    b f01for01

f01finfor01:
    cbz x4, f01sinextension01       // Sin extensión: el sufijo se agrega al final
    mov x1, x4                      // Con extensión: el sufijo reemplaza la extensión original

f01sinextension01:
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
 * Usada para duplicar la imagen original en los buffers de trabajo.
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
 * f03LeerLinea:
 *****Descripción**********************************
 * Lee una línea completa de la entrada estándar byte por byte y la
 * guarda en el buffer terminada en nulo, sin el salto de línea. Si la
 * línea excede la capacidad, descarta el resto de la línea.
 *****Retorno**************************************
 * x0: Longitud de la línea (>= 0), -1 si la entrada terminó sin datos
 *     o -2 si la línea excedió la capacidad del buffer
 *****Entradas*************************************
 * x1: Puntero al buffer donde se guarda la línea
 * x2: Capacidad del buffer (incluye el nulo final)
 *****Errores**************************************
 * Ninguno. Los códigos negativos de x0 los interpreta quien llama.
 **************************************************/
f03LeerLinea:
    mov x6, x1                      // Dirección base del buffer de destino
    sub x4, x2, 1                   // Máximo de caracteres almacenables
    mov x3, 0                       // Cantidad de caracteres almacenados
    mov x5, 0                       // Indicador de línea truncada (1 = truncada)
    sub sp, sp, 16                  // Espacio temporal en pila para el byte leído

    // Ciclo: lee un byte por iteración hasta el salto de línea o fin de entrada
f03for01:
    mov x0, STDIN                   // Descriptor de entrada estándar
    mov x1, sp                      // Dirección del byte temporal
    mov x2, 1                       // Cantidad de bytes a leer
    mov x8, SYS_READ                // Syscall read
    svc 0

    cmp x0, 0
    ble f03fin01                    // Fin de la entrada o error de lectura
    ldrb w7, [sp]                   // Byte leído
    cmp w7, 10
    beq f03finfor01
    cmp x3, x4
    bge f03truncada01
    strb w7, [x6, x3]
    add x3, x3, 1
    b f03for01

f03truncada01:
    mov x5, 1                       // Marca la línea como truncada y descarta el byte
    b f03for01

f03fin01:
    cbnz x3, f03finfor01            // Línea final sin salto de línea: se acepta
    cbnz x5, f03finfor01
    add sp, sp, 16
    mov x0, -1                      // Entrada terminada sin datos
    ret

f03finfor01:
    strb wzr, [x6, x3]              // Termina la línea con nulo
    add sp, sp, 16
    cbnz x5, f03largo01
    mov x0, x3                      // Longitud de la línea
    ret

f03largo01:
    mov x0, -2                      // Línea demasiado larga
    ret

/*****Nombre***************************************
 * f04SaltarEspacios:
 *****Descripción**********************************
 * Avanza el puntero sobre espacios en blanco y comentarios (# hasta
 * el fin de línea) del encabezado PPM.
 *****Retorno**************************************
 * x0: Puntero al primer carácter útil (o al final del buffer)
 *****Entradas*************************************
 * x0: Puntero actual dentro del buffer
 * x1: Puntero al final del buffer
 *****Errores**************************************
 * Ninguno
 **************************************************/
f04SaltarEspacios:
    // Ciclo: descarta blancos y comentarios
f04for01:
    cmp x0, x1
    bhs f04finfor01
    ldrb w2, [x0]                   // Carácter actual
    cmp w2, '#'
    beq f04comentario01
    cmp w2, 32
    beq f04sig01
    cmp w2, 9
    blt f04finfor01
    cmp w2, 13
    bgt f04finfor01
f04sig01:
    add x0, x0, 1
    b f04for01

    // Ciclo: descarta un comentario hasta el salto de línea
f04comentario01:
    cmp x0, x1
    bhs f04finfor01
    ldrb w2, [x0], 1                // Carácter del comentario
    cmp w2, 10
    bne f04comentario01
    b f04for01

f04finfor01:
    ret

/*****Nombre***************************************
 * f05LeerEntero:
 *****Descripción**********************************
 * Lee un número decimal sin signo desde el buffer.
 *****Retorno**************************************
 * x0: Puntero al primer carácter posterior al número
 * x2: Valor leído
 * x3: 1 si se leyó un número válido, 0 si no hubo dígitos o excede MAX_DIMENSION
 *****Entradas*************************************
 * x0: Puntero actual dentro del buffer
 * x1: Puntero al final del buffer
 *****Errores**************************************
 * Ninguno. El llamador interpreta x3 = 0 como error 04.
 **************************************************/
f05LeerEntero:
    mov x2, 0                       // Valor acumulado
    mov x3, 0                       // Indicador de dígitos leídos
    mov x6, MAX_DIMENSION           // Valor máximo aceptado

    // Ciclo: acumula un dígito por iteración
f05for01:
    cmp x0, x1
    bhs f05finfor01
    ldrb w4, [x0]                   // Carácter actual
    sub w4, w4, '0'
    cmp w4, 9
    bhi f05finfor01
    mov x5, 10                      // Base decimal
    mul x2, x2, x5
    add x2, x2, x4
    cmp x2, x6
    bhi f05desborde01
    mov x3, 1
    add x0, x0, 1
    b f05for01

f05desborde01:
    mov x3, 0                       // Número fuera de rango
f05finfor01:
    ret

/*****Nombre***************************************
 * f06EscribirSalida:
 *****Descripción**********************************
 * Crea el archivo indicado en RutaSalida, escribe en él x2 bytes del
 * buffer x1 (repitiendo ante escrituras parciales) y lo cierra.
 *****Retorno**************************************
 * x0: 0 si se escribió correctamente, -1 si hubo error
 *****Entradas*************************************
 * x1: Puntero al buffer a escribir
 * x2: Cantidad de bytes a escribir
 *****Errores**************************************
 * Ninguno. El llamador interpreta x0 = -1 como error 06.
 **************************************************/
f06EscribirSalida:
    mov x4, x1                      // Puntero al siguiente byte por escribir
    mov x5, x2                      // Cantidad de bytes restantes por escribir
    mov x0, AT_FDCWD                // Directorio base: el actual
    ldr x1, =RutaSalida             // Ruta del archivo de salida
    mov x2, FLAGS_ESCRITURA         // Flags de apertura para escritura
    mov x3, PERMISOS                // Permisos del archivo creado
    mov x8, SYS_OPENAT              // Syscall openat
    svc 0
    cmp x0, 0
    blt f06fallo01
    mov x6, x0                      // Descriptor del archivo de salida

    // Ciclo: escribe hasta agotar los bytes pendientes
f06for01:
    cbz x5, f06finfor01
    mov x0, x6                      // Descriptor donde se escribe
    mov x1, x4                      // Dirección de los bytes pendientes
    mov x2, x5                      // Cantidad de bytes pendientes
    mov x8, SYS_WRITE               // Syscall write
    svc 0
    cmp x0, 0
    ble f06errorescritura01
    add x4, x4, x0
    sub x5, x5, x0
    b f06for01

f06finfor01:
    mov x0, x6                      // Descriptor a cerrar
    mov x8, SYS_CLOSE               // Syscall close
    svc 0
    mov x0, 0                       // Escritura correcta
    ret

f06errorescritura01:
    mov x0, x6                      // Descriptor a cerrar
    mov x8, SYS_CLOSE               // Syscall close
    svc 0
f06fallo01:
    mov x0, -1                      // Error al crear o escribir el archivo
    ret

/*****Nombre***************************************
 * f07MostrarBienvenida:
 *****Descripción**********************************
 * Punto de entrada del programa. Imprime el título y continúa
 * con el menú principal.
 *****Retorno**************************************
 * Ninguno. Continúa en f08MostrarMenu.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * Ninguno
 **************************************************/
_start:
f07MostrarBienvenida:
    mov x0, STDOUT                  // Descriptor de salida estándar
    ldr x1, =MensajeBienvenida      // Dirección del mensaje a imprimir
    ldr x2, =LEN_BIENVENIDA         // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0

/*****Nombre***************************************
 * f08MostrarMenu:
 *****Descripción**********************************
 * Imprime el menú principal.
 *****Retorno**************************************
 * Ninguno. Continúa en f09ProcesarSeleccion.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * Ninguno
 **************************************************/
f08MostrarMenu:
    mov x0, STDOUT                  // Descriptor de salida estándar
    ldr x1, =MensajeMenu            // Dirección del mensaje a imprimir
    ldr x2, =LEN_MENU               // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0

/*****Nombre***************************************
 * f09ProcesarSeleccion:
 *****Descripción**********************************
 * Lee la opción del usuario. Solo acepta un único carácter entre '0'
 * y '5'. La opción válida queda en x28 y se solicita la ruta de la
 * imagen; la opción 0 termina el programa.
 *****Retorno**************************************
 * x28: Carácter de la opción elegida ('1' a '5')
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * 02: La opción elegida es inválida
 **************************************************/
f09ProcesarSeleccion:
    ldr x1, =SeleccionUsuario       // Buffer donde se guarda la opción
    mov x2, SELECCION_SIZE          // Capacidad del buffer
    bl f03LeerLinea

    cmp x0, 0
    bge f09conlinea01
    cmn x0, 1                       // Compara x0 con -1 (fin de la entrada)
    beq f31Salir
    b f26ErrorEleccion              // -2: línea demasiado larga

f09conlinea01:
    cmp x0, 1
    bne f26ErrorEleccion            // Vacía o con más de un carácter

    ldr x1, =SeleccionUsuario       // Buffer con la opción leída
    ldrb w0, [x1]                   // Carácter de la opción elegida
    cmp w0, '0'
    beq f31Salir
    cmp w0, '1'
    blt f26ErrorEleccion
    cmp w0, '5'
    bgt f26ErrorEleccion
    mov x28, x0                     // Opción elegida (se conserva hasta aplicar el filtro)

/*****Nombre***************************************
 * f10SolicitarRuta:
 *****Descripción**********************************
 * Solicita la ubicación relativa de la imagen y la lee de la entrada
 * estándar como una línea terminada en nulo.
 *****Retorno**************************************
 * Ninguno. La ruta queda en RutaArchivo. Continúa en f11AbrirArchivo.
 *****Entradas*************************************
 * x28: Opción elegida en el menú
 *****Errores**************************************
 * 03: La ruta está vacía o es demasiado larga
 **************************************************/
f10SolicitarRuta:
    mov x0, STDOUT                  // Descriptor de salida estándar
    ldr x1, =MensajeSolicitar       // Dirección del mensaje a imprimir
    ldr x2, =LEN_SOLICITAR          // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0

    ldr x1, =RutaArchivo            // Buffer donde se guarda la ruta
    mov x2, RUTA_SIZE               // Capacidad del buffer
    bl f03LeerLinea

    cmp x0, 0
    bgt f11AbrirArchivo
    beq f27ErrorRutaInvalida        // Ruta vacía
    cmn x0, 1                       // Compara x0 con -1 (fin de la entrada)
    beq f31Salir
    b f27ErrorRutaInvalida          // -2: ruta demasiado larga

/*****Nombre***************************************
 * f11AbrirArchivo:
 *****Descripción**********************************
 * Abre en modo lectura el archivo indicado en RutaArchivo.
 *****Retorno**************************************
 * x19: Descriptor del archivo abierto
 *****Entradas*************************************
 * Ninguna. Usa la ruta almacenada en RutaArchivo.
 *****Errores**************************************
 * 01: No se pudo abrir el archivo
 **************************************************/
f11AbrirArchivo:
    mov x0, AT_FDCWD                // Directorio base: el actual
    ldr x1, =RutaArchivo            // Ruta del archivo a abrir
    mov x2, 0                       // Flags: solo lectura
    mov x8, SYS_OPENAT              // Syscall openat
    svc 0

    cmp x0, 0
    blt f25ErrorRuta
    mov x19, x0                     // Descriptor del archivo de entrada

/*****Nombre***************************************
 * f12LeerArchivo:
 *****Descripción**********************************
 * Lee el archivo completo en BufferImagenOriginal (repitiendo ante
 * lecturas parciales), verifica que no exceda BUFFER_SIZE y lo cierra.
 *****Retorno**************************************
 * x20: Cantidad de bytes leídos
 *****Entradas*************************************
 * x19: Descriptor del archivo abierto
 *****Errores**************************************
 * 01: No se pudo leer el archivo
 * 05: El archivo supera el tamaño máximo permitido
 **************************************************/
f12LeerArchivo:
    mov x20, 0                      // Total de bytes leídos
    mov x22, 0                      // Código de error (0 = sin error, 1 = lectura, 2 = tamaño)

    // Ciclo: lee hasta fin de archivo o hasta llenar el buffer
f12for01:
    ldr x2, =BUFFER_SIZE            // Capacidad total del buffer
    sub x2, x2, x20                 // Espacio libre restante
    cbz x2, f12verificar01
    mov x0, x19                     // Descriptor del archivo a leer
    ldr x1, =BufferImagenOriginal   // Dirección base del buffer
    add x1, x1, x20                 // Dirección donde continúa la lectura
    mov x8, SYS_READ                // Syscall read
    svc 0
    cmp x0, 0
    blt f12errorlectura01
    beq f12finfor01                 // Fin de archivo
    add x20, x20, x0
    b f12for01

    // Buffer lleno: si aún quedan datos en el archivo, es demasiado grande
f12verificar01:
    sub sp, sp, 16                  // Espacio temporal en pila para un byte
    mov x0, x19                     // Descriptor del archivo a leer
    mov x1, sp                      // Dirección del byte temporal
    mov x2, 1                       // Cantidad de bytes a leer
    mov x8, SYS_READ                // Syscall read
    svc 0
    add sp, sp, 16
    cmp x0, 0
    blt f12errorlectura01
    beq f12finfor01
    mov x22, 2                      // Quedaban datos: archivo demasiado grande
    b f12finfor01

f12errorlectura01:
    mov x22, 1                      // Error de lectura

f12finfor01:
    mov x0, x19                     // Descriptor del archivo a cerrar
    mov x8, SYS_CLOSE               // Syscall close
    svc 0

    cmp x22, 1
    beq f25ErrorRuta
    cmp x22, 2
    beq f29ErrorTamano

/*****Nombre***************************************
 * f13ValidarEncabezado:
 *****Descripción**********************************
 * Valida y analiza el encabezado PPM: "P6", ancho, alto y maxval 255,
 * admitiendo comentarios y espacios entre campos. Verifica que el
 * archivo contenga todos los bytes de píxeles esperados.
 *****Retorno**************************************
 * x21: Ancho de la imagen en píxeles
 * x24: Alto de la imagen en píxeles
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles (ancho * alto * 3)
 *****Entradas*************************************
 * x20: Cantidad de bytes leídos
 *****Errores**************************************
 * 04: El archivo no es una imagen PPM válida
 **************************************************/
f13ValidarEncabezado:
    ldr x25, =BufferImagenOriginal  // Dirección base de la imagen
    mov x0, x25                     // Puntero de recorrido del encabezado
    add x1, x25, x20                // Puntero al final de los datos leídos

    cmp x20, 2
    blt f28ErrorFormato
    ldrb w3, [x0]                   // Primer carácter del número mágico
    cmp w3, 'P'
    bne f28ErrorFormato
    ldrb w3, [x0, 1]                // Segundo carácter del número mágico
    cmp w3, '6'
    bne f28ErrorFormato
    add x0, x0, 2

    bl f04SaltarEspacios
    bl f05LeerEntero                // Ancho
    cbz x3, f28ErrorFormato
    cbz x2, f28ErrorFormato
    mov x21, x2                     // Ancho de la imagen

    bl f04SaltarEspacios
    bl f05LeerEntero                // Alto
    cbz x3, f28ErrorFormato
    cbz x2, f28ErrorFormato
    mov x24, x2                     // Alto de la imagen

    bl f04SaltarEspacios
    bl f05LeerEntero                // Valor máximo de color
    cbz x3, f28ErrorFormato
    cmp x2, 255
    bne f28ErrorFormato

    cmp x0, x1
    bhs f28ErrorFormato             // Falta el separador antes de los píxeles
    ldrb w3, [x0]                   // Único blanco que separa el encabezado de los píxeles
    cmp w3, 32
    beq f13separador01
    cmp w3, 9
    blt f28ErrorFormato
    cmp w3, 13
    bgt f28ErrorFormato
f13separador01:
    add x0, x0, 1
    sub x26, x0, x25                // Tamaño del encabezado

    mul x27, x21, x24               // Cantidad de píxeles
    mov x4, 3                       // Bytes por píxel
    mul x27, x27, x4                // Cantidad de bytes de píxeles
    sub x5, x20, x26                // Bytes de píxeles disponibles en el archivo
    cmp x5, x27
    blo f28ErrorFormato             // Archivo truncado

/*****Nombre***************************************
 * f14CopiarImagen:
 *****Descripción**********************************
 * Copia la imagen original al buffer sobre el que se aplicarán
 * los filtros.
 *****Retorno**************************************
 * Ninguno. Continúa en f15EjecutarFiltro.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 *****Errores**************************************
 * Ninguno
 **************************************************/
f14CopiarImagen:
    ldr x0, =BufferImagenOriginal   // Puntero de origen
    ldr x1, =BufferImagenFiltro     // Puntero de destino
    mov x2, x20                     // Cantidad de bytes a copiar
    bl f02CopiarABuffersCanal

/*****Nombre***************************************
 * f15EjecutarFiltro:
 *****Descripción**********************************
 * Salta a la función del filtro correspondiente a la opción elegida.
 *****Retorno**************************************
 * Ninguno. Continúa en la función del filtro.
 *****Entradas*************************************
 * x28: Carácter de la opción elegida ('1' a '5')
 *****Errores**************************************
 * 02: La opción elegida es inválida
 **************************************************/
f15EjecutarFiltro:
    cmp x28, '1'
    beq f16FiltroInversion
    cmp x28, '2'
    beq f17FiltroEscalaGrises
    cmp x28, '3'
    beq f21SepararCanalRojo
    cmp x28, '4'
    beq f19FiltroDesenfoque
    cmp x28, '5'
    beq f18FiltroSalPimienta
    b f26ErrorEleccion

/*****Nombre***************************************
 * f16FiltroInversion:
 *****Descripción**********************************
 * Invierte el color de cada byte de píxel (XOR con 0xFF).
 *****Retorno**************************************
 * Ninguno. Continúa en f20EscribirArchivo.
 *****Entradas*************************************
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * Ninguno
 **************************************************/
f16FiltroInversion:
    ldr x10, =SufijoInverted        // Sufijo del archivo de salida
    bl f01GenerarNombreSalida

    ldr x0, =BufferImagenFiltro     // Dirección base de la imagen
    add x0, x0, x26                 // Puntero al primer píxel
    mov x2, x27                     // Contador de bytes restantes

    // Ciclo: invierte cada byte de píxel
f16for01:
    cbz x2, f16finfor01
    ldrb w3, [x0]                   // Valor del byte actual
    eor w3, w3, #0xFF
    strb w3, [x0], 1
    sub x2, x2, 1
    b f16for01

f16finfor01:
    b f20EscribirArchivo

/*****Nombre***************************************
 * f17FiltroEscalaGrises:
 *****Descripción**********************************
 * Reemplaza cada píxel por el promedio de sus componentes R, G y B.
 *****Retorno**************************************
 * Ninguno. Continúa en f20EscribirArchivo.
 *****Entradas*************************************
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * Ninguno
 **************************************************/
f17FiltroEscalaGrises:
    ldr x10, =SufijoGreyscale       // Sufijo del archivo de salida
    bl f01GenerarNombreSalida

    ldr x0, =BufferImagenFiltro     // Dirección base de la imagen
    add x0, x0, x26                 // Puntero al píxel actual
    mov x2, x27                     // Contador de bytes restantes

    // Ciclo: procesa un píxel (3 bytes) por iteración
f17for01:
    cmp x2, 2
    ble f20EscribirArchivo

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
    b f17for01

/*****Nombre***************************************
 * f18FiltroSalPimienta:
 *****Descripción**********************************
 * Cada píxel tiene 25% de probabilidad de cambiar; si cambia, se
 * vuelve blanco o negro con igual probabilidad. Usa un generador
 * congruencial lineal inicializado con el contador de tiempo.
 *****Retorno**************************************
 * Ninguno. Continúa en f20EscribirArchivo.
 *****Entradas*************************************
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * Ninguno
 **************************************************/
f18FiltroSalPimienta:
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
f18for01:
    cmp x2, 2
    ble f20EscribirArchivo

    mul x9, x9, x11
    add x9, x9, x13
    lsr x12, x9, #30                // Bits aleatorios: ¿se altera el píxel?
    and x12, x12, #3
    cmp x12, 0
    bne f18sigpixel

    mul x9, x9, x11
    add x9, x9, x13
    lsr x12, x9, #31                // Bit aleatorio: negro (1) o blanco (0)
    and x12, x12, #1
    cmp x12, 0
    beq f18pixelblanco

f18pixelnegro:
    strb wzr, [x0]
    strb wzr, [x0, 1]
    strb wzr, [x0, 2]
    b f18sigpixel

f18pixelblanco:
    mov w14, #255                   // Valor blanco (x13 es el incremento del generador)
    strb w14, [x0]
    strb w14, [x0, 1]
    strb w14, [x0, 2]

f18sigpixel:
    add x0, x0, 3
    sub x2, x2, 3
    b f18for01

/*****Nombre***************************************
 * f19FiltroDesenfoque:
 *****Descripción**********************************
 * Reemplaza cada byte interno de la imagen por el promedio de los
 * 9 bytes vecinos del mismo canal, leídos de la imagen original.
 * Los píxeles del borde no se modifican.
 *****Retorno**************************************
 * Ninguno. Continúa en f20EscribirArchivo.
 *****Entradas*************************************
 * x21: Ancho de la imagen en píxeles
 * x24: Alto de la imagen en píxeles
 * x26: Tamaño del encabezado en bytes
 *****Errores**************************************
 * Ninguno
 **************************************************/
f19FiltroDesenfoque:
    ldr x10, =SufijoBlur            // Sufijo del archivo de salida
    bl f01GenerarNombreSalida

    mov x14, x21                    // Ancho de la imagen en píxeles
    mov x16, x24                    // Alto de la imagen en píxeles
    mov x15, 3                      // Bytes por píxel
    mul x15, x14, x15               // Bytes por fila

    ldr x1, =BufferImagenOriginal   // Dirección base de la imagen original
    add x1, x1, x26                 // Puntero a los píxeles originales
    ldr x0, =BufferImagenFiltro     // Dirección base de la imagen filtrada
    add x0, x0, x26                 // Puntero a los píxeles filtrados

    cmp x14, 3
    blt f20EscribirArchivo
    cmp x16, 3
    blt f20EscribirArchivo

    mov x17, 1                      // Fila actual y

    // Ciclo: recorre las filas internas de la imagen
f19fory01:
    sub x4, x16, 1                  // Límite superior de filas
    cmp x17, x4
    beq f20EscribirArchivo

    mov x18, 1                      // Columna actual x

    // Ciclo: recorre las columnas internas de la fila
f19forx01:
    sub x4, x14, 1                  // Límite superior de columnas
    cmp x18, x4
    beq f19sigy01

    mul x12, x17, x15               // Desplazamiento de la fila
    mov x4, 3                       // Bytes por píxel
    mul x5, x18, x4
    add x12, x12, x5                // Desplazamiento del píxel

    mov x13, 0                      // Canal actual (0=R, 1=G, 2=B)

    // Ciclo: promedia los 9 vecinos de cada canal del píxel
f19forcanal01:
    cmp x13, 3
    beq f19sigx01

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
    b f19forcanal01

f19sigx01:
    add x18, x18, 1
    b f19forx01

f19sigy01:
    add x17, x17, 1
    b f19fory01

/*****Nombre***************************************
 * f20EscribirArchivo:
 *****Descripción**********************************
 * Escribe en el archivo de salida el contenido de BufferImagenFiltro.
 *****Retorno**************************************
 * Ninguno. Continúa en f24ImprimirImagenLista.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 *****Errores**************************************
 * 06: No se pudo crear o escribir el archivo de salida
 **************************************************/
f20EscribirArchivo:
    ldr x1, =BufferImagenFiltro     // Buffer a escribir
    mov x2, x20                     // Cantidad de bytes a escribir
    bl f06EscribirSalida
    cmp x0, 0
    blt f30ErrorSalida
    b f24ImprimirImagenLista

/*****Nombre***************************************
 * f21SepararCanalRojo:
 *****Descripción**********************************
 * Genera y guarda la imagen del canal rojo (verde y azul en cero).
 *****Retorno**************************************
 * Ninguno. Continúa en f22SepararCanalVerde.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * 06: No se pudo crear o escribir el archivo de salida
 **************************************************/
f21SepararCanalRojo:
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
f21for01:
    cmp x2, 2
    ble f21finfor01
    ldrb w3, [x0]                   // Componente rojo
    strb w3, [x0], 1

    mov w3, 0                       // Valor cero para verde y azul
    strb w3, [x0], 1
    strb w3, [x0], 1

    sub x2, x2, 3
    b f21for01

f21finfor01:
    ldr x1, =BufferCanalRojo        // Buffer a escribir
    mov x2, x20                     // Cantidad de bytes a escribir
    bl f06EscribirSalida
    cmp x0, 0
    blt f30ErrorSalida

/*****Nombre***************************************
 * f22SepararCanalVerde:
 *****Descripción**********************************
 * Genera y guarda la imagen del canal verde (rojo y azul en cero).
 *****Retorno**************************************
 * Ninguno. Continúa en f23SepararCanalAzul.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * 06: No se pudo crear o escribir el archivo de salida
 **************************************************/
f22SepararCanalVerde:
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
f22for01:
    cmp x2, 2
    ble f22finfor01
    mov w3, 0                       // Valor cero para rojo
    strb w3, [x0], 1

    ldrb w3, [x0]                   // Componente verde
    strb w3, [x0], 1

    mov w3, 0                       // Valor cero para azul
    strb w3, [x0], 1

    sub x2, x2, 3
    b f22for01

f22finfor01:
    ldr x1, =BufferCanalVerde       // Buffer a escribir
    mov x2, x20                     // Cantidad de bytes a escribir
    bl f06EscribirSalida
    cmp x0, 0
    blt f30ErrorSalida

/*****Nombre***************************************
 * f23SepararCanalAzul:
 *****Descripción**********************************
 * Genera y guarda la imagen del canal azul (rojo y verde en cero).
 *****Retorno**************************************
 * Ninguno. Continúa en f24ImprimirImagenLista.
 *****Entradas*************************************
 * x20: Cantidad de bytes de la imagen
 * x26: Tamaño del encabezado en bytes
 * x27: Cantidad de bytes de píxeles
 *****Errores**************************************
 * 06: No se pudo crear o escribir el archivo de salida
 **************************************************/
f23SepararCanalAzul:
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
f23for01:
    cmp x2, 2
    ble f23finfor01
    mov w3, 0                       // Valor cero para rojo
    strb w3, [x0], 1

    mov w3, 0                       // Valor cero para verde
    strb w3, [x0], 1

    ldrb w3, [x0]                   // Componente azul
    strb w3, [x0], 1

    sub x2, x2, 3
    b f23for01

f23finfor01:
    ldr x1, =BufferCanalAzul        // Buffer a escribir
    mov x2, x20                     // Cantidad de bytes a escribir
    bl f06EscribirSalida
    cmp x0, 0
    blt f30ErrorSalida

/*****Nombre***************************************
 * f24ImprimirImagenLista:
 *****Descripción**********************************
 * Informa que la imagen fue procesada y regresa al menú.
 *****Retorno**************************************
 * Ninguno. Continúa en f08MostrarMenu.
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

    b f08MostrarMenu

/*****Nombre***************************************
 * f25ErrorRuta:
 *****Descripción**********************************
 * Muestra el error de apertura/lectura de archivo y vuelve a
 * solicitar la ruta.
 *****Retorno**************************************
 * Ninguno. Continúa en f10SolicitarRuta.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * 01: No se pudo abrir o leer el archivo
 **************************************************/
f25ErrorRuta:
    mov x0, STDERR                  // Descriptor de error estándar
    ldr x1, =Error01                // Mensaje del error #01
    ldr x2, =LEN_ERROR01            // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0
    b f10SolicitarRuta

/*****Nombre***************************************
 * f26ErrorEleccion:
 *****Descripción**********************************
 * Muestra el error de opción inválida y regresa al menú.
 *****Retorno**************************************
 * Ninguno. Continúa en f08MostrarMenu.
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
    b f08MostrarMenu

/*****Nombre***************************************
 * f27ErrorRutaInvalida:
 *****Descripción**********************************
 * Muestra el error de ruta vacía o demasiado larga y vuelve a
 * solicitar la ruta.
 *****Retorno**************************************
 * Ninguno. Continúa en f10SolicitarRuta.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * 03: La ruta está vacía o es demasiado larga
 **************************************************/
f27ErrorRutaInvalida:
    mov x0, STDERR                  // Descriptor de error estándar
    ldr x1, =Error03                // Mensaje del error #03
    ldr x2, =LEN_ERROR03            // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0
    b f10SolicitarRuta

/*****Nombre***************************************
 * f28ErrorFormato:
 *****Descripción**********************************
 * Muestra el error de archivo que no es un PPM válido y vuelve a
 * solicitar la ruta.
 *****Retorno**************************************
 * Ninguno. Continúa en f10SolicitarRuta.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * 04: El archivo no es una imagen PPM válida
 **************************************************/
f28ErrorFormato:
    mov x0, STDERR                  // Descriptor de error estándar
    ldr x1, =Error04                // Mensaje del error #04
    ldr x2, =LEN_ERROR04            // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0
    b f10SolicitarRuta

/*****Nombre***************************************
 * f29ErrorTamano:
 *****Descripción**********************************
 * Muestra el error de archivo demasiado grande y vuelve a solicitar
 * la ruta.
 *****Retorno**************************************
 * Ninguno. Continúa en f10SolicitarRuta.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * 05: El archivo supera el tamaño máximo permitido
 **************************************************/
f29ErrorTamano:
    mov x0, STDERR                  // Descriptor de error estándar
    ldr x1, =Error05                // Mensaje del error #05
    ldr x2, =LEN_ERROR05            // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0
    b f10SolicitarRuta

/*****Nombre***************************************
 * f30ErrorSalida:
 *****Descripción**********************************
 * Muestra el error al crear o escribir el archivo de salida y
 * regresa al menú.
 *****Retorno**************************************
 * Ninguno. Continúa en f08MostrarMenu.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * 06: No se pudo crear o escribir el archivo de salida
 **************************************************/
f30ErrorSalida:
    mov x0, STDERR                  // Descriptor de error estándar
    ldr x1, =Error06                // Mensaje del error #06
    ldr x2, =LEN_ERROR06            // Longitud del mensaje
    mov x8, SYS_WRITE               // Syscall write
    svc 0
    b f08MostrarMenu

/*****Nombre***************************************
 * f31Salir:
 *****Descripción**********************************
 * Termina el programa con código de salida 0.
 *****Retorno**************************************
 * Ninguno. El programa finaliza.
 *****Entradas*************************************
 * Ninguna
 *****Errores**************************************
 * Ninguno
 **************************************************/
f31Salir:
    mov x0, 0                       // Código de salida
    mov x8, SYS_EXIT                // Syscall exit
    svc 0
