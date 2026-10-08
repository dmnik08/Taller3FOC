//*****Datos administrativos************************
// * Nombre del archivo: main.s
// * Tipo de archivo:Codigo fuente ensamblador AArch64
// * Proyecto: Filtros de imagenes PPM
// * Autor:Dóminick Viales Mora, 	Jahrell Gourzong Ortiz
//
//*****Descripcion**********************************
// * Procesador de imagenes PPM.
// * Aplica filtros de inversion de color, escala de grises,
// * sal y pimienta, desenfoque por promedio, y separacion de canales RGB
// 
//
//*****Version**************************************
// * ## | 07/10/2026 18:00 | Dóminick Viales, Jahrell Gourzong
// *
//**************************************************/
.data
	 Msg_bienvenida: .ascii "\n PROCESADOR DE IMAGENES PPM \n\n"  //Titulo del programa
	 Len_bienvenida =  .-Msg_bienvenida     //Longitud del mensaje 

	 Msg_menu: .ascii "[1] Aplicar filtro de inversion de color.\n[2] Aplicar filtro de escala de grises.\n[3] Separacion de canales.\n[4] Desenfoque por  promedio.\n[5] Filtro sal y pimienta\n[0] Salir.\n"  //Menu principal del programa
	 Len_msg_menu = .-Msg_menu              //Longitud del mensaje del menu
	 Msg_solicitar: .ascii "Introduzca la ubicacion relativa de la imagen:"  //Mensaje para solicitar la ruta de la imagen
	 Len_solicitar = .-Msg_solicitar        //Longitud del mensaje de solicitud

	Msg_error_ruta: .ascii "Error:No se pudo abrir el archivo.\n\n"  //Mensaje de error al abrir archivo
    	Len_error_ruta = .-Msg_error_ruta       //Longitud del mensaje de error de ruta

	Msg_exito_abrir: .ascii "El archivo se abrio correctamente\n\n"  //Mensaje de exito al abrir archivo
	Len_exito_abrir = .-Msg_exito_abrir     //Longitud del mensaje de exito

	Msg_error_eleccion: .ascii "Error: La opcion elegida es invalida!\n\n"  //Mensaje de opcion invalida en el menu
	Len_msg_error_eleccion = .-Msg_error_eleccion  //Longitud del mensaje de error de eleccion

	Msg_imagen_lista:  .ascii "Imagen Lista!!\n\n"
        Len_msg_imagen_lista= . -Msg_imagen_lista

	Sufijo_inverted: .asciz "_inverted"    //Sufijo para archivo de salida del filtro de inversion
	Sufijo_greyscale: .asciz "_greyscale"  //Sufijo para archivo de salida del filtro de escala de grises
	Sufijo_saltpeper: .asciz "_saltpeper"  //Sufijo para archivo de salida del filtro sal y pimienta
	Sufijo_canal_rojo: .asciz "_red"       //Sufijo para archivo de salida del canal rojo
	Sufijo_canal_verde: .asciz "_green"    //Sufijo para archivo de salida del canal verde
	Sufijo_canal_azul: .asciz "_blue"      //Sufijo para archivo de salida del canal azul
	Sufijo_blur: .asciz "_blur"  	       //Sufijo para archivo de salida del filtro de desenfoque
	Ext_ppm: .asciz ".ppm"  	       //Extension del archivo de salida

.bss
    Ruta_archivo:           .space 256        //Espacio para almacenar la ruta de entrada
    Ruta_salida:            .space 256        //Espacio para almacenar la ruta de salida
    Seleccion_usuario:      .space 4          //Espacio para almacenar la seleccion del usuario
    Buffer_imagen_original: .space 2000000    //Espacio para almacenar la imagen original
    Buffer_imagen_filtro:   .space 2000000    //Espacio para almacenar la imagen con filtro
    Buffer_canal_rojo:      .space 2000000    //Espacio para almacenar el canal rojo
    Buffer_canal_verde:     .space 2000000    //Espacio para almacenar el canal verde
    Buffer_canal_azul:	    .space 2000000    //Espacio para almacenar el canal azul

.text
.global _start

_start:
    mov x0, 1
    ldr x1, =Msg_bienvenida
    ldr x2, =Len_bienvenida
    mov x8, 64
    svc 0
    b solicitar_ruta

solicitar_ruta:
    mov x0, 1
    ldr x1, =Msg_solicitar
    ldr x2, =Len_solicitar
    mov x8, 64
    svc 0

    mov x0, 0
    ldr x1, =Ruta_archivo
    mov x2, 255
    mov x8, 63
    svc 0

    sub x0, x0, 1
    ldr x1, =Ruta_archivo
    strb wzr, [x1, x0]

abrir_archivo:
    mov x0, -100
    ldr x1, =Ruta_archivo
    mov x2, 0
    mov x8, 56
    svc 0

    cmp x0, 0
    blt error_ruta
    mov x19, x0

leer_archivo:
    mov x0, x19
    ldr x1, =Buffer_imagen_original
    ldr x2, =2000000
    mov x8, 63
    svc 0

    cmp x0, 0
    ble error_ruta
    mov x20, x0

    mov x0, x19
    mov x8, 57
    svc 0

    mov x0, 1
    ldr x1, =Msg_exito_abrir
    ldr x2, =Len_exito_abrir
    mov x8, 64
    svc 0

    b copiar_imagen

copiar_imagen:
    ldr x0, =Buffer_imagen_original
    ldr x1, =Buffer_imagen_filtro
    mov x2, x20

loop_copia_imagen:
    cbz x2, fin_loop_copiar_imagen
    ldrb w3, [x0], 1
    strb w3, [x1], 1
    sub x2, x2, 1
    b loop_copia_imagen

fin_loop_copiar_imagen:
    b apuntar_inicio_imagen

apuntar_inicio_imagen:
    ldr x25, =Buffer_imagen_filtro
    mov x21, 0

buscar_inicio_buffer:
    ldrb w0, [x25], 1
    cmp w0, 10
    bne buscar_inicio_buffer
    add x21, x21, 1
    cmp x21, 3
    blt buscar_inicio_buffer

    ldr x0, =Buffer_imagen_filtro
    sub x26, x25, x0
    sub x27, x20, x26
    b mostrar_Menu

mostrar_Menu:
    mov x0, 1
    ldr x1, =Msg_menu
    ldr x2, =Len_msg_menu
    mov x8, 64
    svc 0

procesar_seleccion_usuario:
    mov x0, 0
    ldr x1, =Seleccion_usuario
    mov x2, 2
    mov x8, 63
    svc 0

    ldrb w0, [x1]
    cmp w0, '1'
    beq filtro_invertir_color

    cmp w0, '2'
    beq filtro_escala_grises

    cmp w0, '3'
    beq separacion_canal_rojo

    cmp w0, '4'
    beq filtro_desenfoque

    cmp w0, '5'
    beq filtro_sal_pimienta

    cmp w0, '0'
    beq salir

    b error_eleccion_usuario

filtro_invertir_color:
    ldr x10, =Sufijo_inverted
    bl f01GenerarNombreSalida

    ldr x0, =Buffer_imagen_filtro
    add x0, x0, x26
    mov x2, x27

loop_aplicar_filtro_inversion:
    cbz x2, fin_inversion
    ldrb w3, [x0]
    eor w3, w3, #0xFF
    strb w3, [x0], 1
    sub x2, x2, 1
    b loop_aplicar_filtro_inversion

fin_inversion:
    b escribir_archivo_inversion

filtro_escala_grises:
    ldr x10, =Sufijo_greyscale
    bl f01GenerarNombreSalida

    ldr x0, =Buffer_imagen_filtro
    add x0, x0, x26
    mov x2, x27

loop_aplicar_escala_grises:
    cmp x2, 2
    ble fin_aplicacion_filtros

    ldrb w3, [x0]
    ldrb w4, [x0, 1]
    ldrb w5, [x0, 2]

    add w6, w3, w4
    add w6, w6, w5
    mov w7, 3
    udiv w6, w6, w7

    strb w6, [x0]
    strb w6, [x0, 1]
    strb w6, [x0, 2]

    add x0, x0, 3
    sub x2, x2, 3
    b loop_aplicar_escala_grises

filtro_sal_pimienta:
    ldr x10, =Sufijo_saltpeper
    bl f01GenerarNombreSalida

    ldr x0, =Buffer_imagen_filtro
    add x0, x0, x26
    mov x2, x27

    mrs x9, cntvct_el0
    mov x13, #2531
    lsl x13, x13, #10
    add x13, x13, #35
    movk x11, #0x6c07, lsl 0
    movk x11, #0x343f, lsl 16

loop_sal_pimienta:
    cmp x2, 2
    ble fin_aplicacion_filtros

    mul x9, x9, x11
    add x9, x9, x13
    lsr x12, x9, #30
    and x12, x12, #3
    cmp x12, 0
    bne sig_pixel

    mul x9, x9, x11
    add x9, x9, x13
    lsr x12, x9, #31
    and x12, x12, #1
    cmp x12, 0
    beq pixel_blanco

pixel_negro:
    strb wzr, [x0]
    strb wzr, [x0, 1]
    strb wzr, [x0, 2]
    b sig_pixel

pixel_blanco:
    mov w13, #255
    strb w13, [x0]
    strb w13, [x0, 1]
    strb w13, [x0, 2]

sig_pixel:
    add x0, x0, 3
    sub x2, x2, 3
    b loop_sal_pimienta

filtro_desenfoque:
    ldr x10, =Sufijo_blur
    bl f01GenerarNombreSalida

    ldr x0, =Buffer_imagen_filtro
    add x2, x0, 3

    mov x14, 0
parse_width_loop:
    ldrb w4, [x2], 1
    cmp w4, ' '
    beq parse_width_done
    cmp w4, 10
    beq parse_width_done
    sub w4, w4, '0'
    mov x5, 10
    mul x14, x14, x5
    add x14, x14, x4
    b parse_width_loop

parse_width_done:
    mov x15, 3
    mul x15, x14, x15

    udiv x16, x27, x15

    ldr x1, =Buffer_imagen_original
    add x1, x1, x26
    ldr x0, =Buffer_imagen_filtro
    add x0, x0, x26

    cmp x14, 3
    blt fin_aplicacion_filtros
    cmp x16, 3
    blt fin_aplicacion_filtros

    mov x17, 1

loop_y_blur:
    sub x4, x16, 1
    cmp x17, x4
    beq fin_aplicacion_filtros

    mov x18, 1

loop_x_blur:
    sub x4, x14, 1
    cmp x18, x4
    beq next_y_blur

    mul x12, x17, x15
    mov x4, 3
    mul x5, x18, x4
    add x12, x12, x5

    mov x13, 0

loop_channel_blur:
    cmp x13, 3
    beq next_x_blur

    add x22, x12, x13

    mov x23, 0

    sub x4, x22, x15
    sub x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    add x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    add x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    sub x4, x22, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    add x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

    add x4, x4, 3
    ldrb w5, [x1, x4]
    add x23, x23, x5

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

    mov x4, 9
    udiv x23, x23, x4

    strb w23, [x0, x22]

    add x13, x13, 1
    b loop_channel_blur

next_x_blur:
    add x18, x18, 1
    b loop_x_blur

next_y_blur:
    add x17, x17, 1
    b loop_y_blur

fin_aplicacion_filtros:
    b escribir_archivo

//*****Nombre***************************************
// * f01GenerarNombreSalida:
//
//*****Descripcion**********************************
// * Genera el nombre del archivo de salida concatenando la ruta de
// * entrada (sin extension), el sufijo del filtro y la extension .ppm.
//
//*****Retorno**************************************
// * Ninguno. El resultado se escribe en Ruta_salida.
//
//*****Entradas*************************************
// * x10: Puntero al string del sufijo a agregar al nombre de salida
//
//*****Errores**************************************
// * Ninguno
//
//**************************************************/
f01GenerarNombreSalida:
    ldr x0, =Ruta_archivo
    ldr x1, =Ruta_salida

f01loop1:
    ldrb w2, [x0], 1
    cmp w2, 0
    beq f01appendsuffix
    cmp w2, '.'
    beq f01appendsuffix
    strb w2, [x1], 1
    b f01loop1

f01appendsuffix:
    mov x2, x10             //x10: Puntero al sufijo del filtro (entrada)

f01loop2:
    ldrb w3, [x2], 1
    cmp w3, 0
    beq f01appendext
    strb w3, [x1], 1
    b f01loop2

f01appendext:
    ldr x2, =Ext_ppm

f01loop3:
    ldrb w3, [x2], 1
    strb w3, [x1], 1
    cmp w3, 0
    bne f01loop3
    ret

//*****Nombre***************************************
// * f02CopiarABuffersCanal:
//
//*****Descripcion**********************************
// * Copia x2 bytes desde el buffer origen (x0) al buffer destino (x1).
// * Usada para duplicar la imagen original en los buffers de canal.
//
//*****Retorno**************************************
// * Ninguno.
//
//*****Entradas*************************************
// * x0: Puntero al buffer de origen
// * x1: Puntero al buffer de destino
// * x2: Cantidad de bytes a copiar
//
//*****Errores**************************************
// * Ninguno
//
//**************************************************/
f02CopiarABuffersCanal:
    cbz x2, f02fincopiar    //x2: Cantidad de bytes a copiar (entrada)
    ldrb w3, [x0], 1        //x0: Buffer de origen (entrada)
    strb w3, [x1], 1        //x1: Buffer de destino (entrada)
    sub x2, x2, 1
    b f02CopiarABuffersCanal

f02fincopiar:
    ret

separacion_canal_rojo:
    ldr x0, =Buffer_imagen_original
    ldr x1, =Buffer_canal_rojo
    mov x2, x20
    bl f02CopiarABuffersCanal

    ldr x10, =Sufijo_canal_rojo
    bl f01GenerarNombreSalida

    ldr x0, =Buffer_canal_rojo
    add x0, x0, x26
    mov x2, x27

loop_separar_rojo:
    cbz x2, escribir_canal_rojo
    ldrb w3, [x0]
    strb w3, [x0], 1

    mov w3, 0
    strb w3, [x0], 1
    strb w3, [x0], 1

    sub x2, x2, 3
    b loop_separar_rojo

escribir_canal_rojo:
    mov x0, -100
    ldr x1, =Ruta_salida
    mov x2, 0x241
    mov x3, 0644
    mov x8, 56
    svc 0
    mov x19, x0
    mov x0, x19
    ldr x1, =Buffer_canal_rojo
    mov x2, x20
    mov x8, 64
    svc 0
    mov x0, x19
    mov x8, 57
    svc 0
    b separacion_canal_verde

separacion_canal_verde:
    ldr x0, =Buffer_imagen_original
    ldr x1, =Buffer_canal_verde
    mov x2, x20
    bl f02CopiarABuffersCanal

    ldr x10, =Sufijo_canal_verde
    bl f01GenerarNombreSalida

    ldr x0, =Buffer_canal_verde
    add x0, x0, x26
    mov x2, x27

loop_separar_verde:
    cbz x2, escribir_canal_verde
    mov w3, 0
    strb w3, [x0], 1

    ldrb w3, [x0]
    strb w3, [x0], 1

    mov w3, 0
    strb w3, [x0], 1

    sub x2, x2, 3
    b loop_separar_verde

escribir_canal_verde:
    mov x0, -100
    ldr x1, =Ruta_salida
    mov x2, 0x241
    mov x3, 0644
    mov x8, 56
    svc 0
    mov x19, x0
    mov x0, x19
    ldr x1, =Buffer_canal_verde
    mov x2, x20
    mov x8, 64
    svc 0
    mov x0, x19
    mov x8, 57
    svc 0
    b separacion_canal_azul

separacion_canal_azul:
    ldr x0, =Buffer_imagen_original
    ldr x1, =Buffer_canal_azul
    mov x2, x20
    bl f02CopiarABuffersCanal

    ldr x10, =Sufijo_canal_azul
    bl f01GenerarNombreSalida

    ldr x0, =Buffer_canal_azul
    add x0, x0, x26
    mov x2, x27

loop_separar_azul:
    cbz x2, escribir_canal_azul
    mov w3, 0
    strb w3, [x0], 1

    mov w3, 0
    strb w3, [x0], 1

    ldrb w3, [x0]
    strb w3, [x0], 1

    sub x2, x2, 3
    b loop_separar_azul

escribir_canal_azul:
    mov x0, -100
    ldr x1, =Ruta_salida
    mov x2, 0x241
    mov x3, 0644
    mov x8, 56
    svc 0
    mov x19, x0
    mov x0, x19
    ldr x1, =Buffer_canal_azul
    mov x2, x20
    mov x8, 64
    svc 0
    mov x0, x19
    mov x8, 57
    svc 0
    b imprimir_mensaje_imagen_lista

escribir_archivo_inversion:
    mov x0, -100
    ldr x1, =Ruta_salida
    mov x2, 0x241
    mov x3, 0644
    mov x8, 56
    svc 0

    mov x19, x0
    mov x0, x19
    ldr x1, =Buffer_imagen_filtro
    mov x2, x20
    mov x8, 64
    svc 0

    mov x0, x19
    mov x8, 57
    svc 0

    ldr x0, =Buffer_imagen_original
    ldr x1, =Buffer_imagen_filtro
    mov x2, x20
    bl f02CopiarABuffersCanal
    b imprimir_mensaje_imagen_lista

escribir_archivo:
    mov x0, -100
    ldr x1, =Ruta_salida
    mov x2, 0x241
    mov x3, 0644
    mov x8, 56
    svc 0

    mov x19, x0
    mov x0, x19
    ldr x1, =Buffer_imagen_filtro
    mov x2, x20
    mov x8, 64
    svc 0

    mov x0, x19
    mov x8, 57
    svc 0
    b imprimir_mensaje_imagen_lista

imprimir_mensaje_imagen_lista:
    mov x0, 1
    ldr x1, =Msg_imagen_lista
    ldr x2, =Len_msg_imagen_lista
    mov x8, #64
    svc 0

    b mostrar_Menu

error_ruta:
    mov x0, 2
    ldr x1, =Msg_error_ruta
    ldr x2, =Len_error_ruta
    mov x8, 64
    svc 0
    b solicitar_ruta

error_eleccion_usuario:
    mov x0, 2
    ldr x1, =Msg_error_eleccion
    ldr x2, =Len_msg_error_eleccion
    mov x8, 64
    svc 0
    b mostrar_Menu

salir:
    mov x0, 0
    mov x8, 93
    svc 0
