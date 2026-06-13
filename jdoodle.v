// Modulo principal del sumador completo se definen entradas y salidas
module sumador_completo(
    
    input  A,
    input  B,
    input  Cin,   

    output Sum,   
    output Cout
);
    assign Sum  = A ^ B ^ Cin;
    assign Cout = (A & B) | (B & Cin) | (A & Cin);

endmodule

// Modulo de pruebas para simular el sumador
module main;
    reg  A, B, Cin;
    wire Sum, Cout;

    sumador_completo uut (
        .A(A),
        .B(B),
        .Cin(Cin),
        .Sum(Sum),
        .Cout(Cout)
    );

    initial begin
        // Se imprime el encabezado de la tabla
        $display("A B Cin | Sum Cout");
        $display("--------|----------");

        // Se imprimen las  posibles combinaciones
        {A, B, Cin} = 3'b000; #10; // 0+0+0
        $display("%b %b  %b  |  %b    %b", A, B, Cin, Sum, Cout);
        {A, B, Cin} = 3'b001; #10; // 0+0+1
        $display("%b %b  %b  |  %b    %b", A, B, Cin, Sum, Cout);
        {A, B, Cin} = 3'b010; #10; // 0+1+0
        $display("%b %b  %b  |  %b    %b", A, B, Cin, Sum, Cout);
        {A, B, Cin} = 3'b011; #10; // 0+1+1
        $display("%b %b  %b  |  %b    %b", A, B, Cin, Sum, Cout);
        {A, B, Cin} = 3'b100; #10; // 1+0+0
        $display("%b %b  %b  |  %b    %b", A, B, Cin, Sum, Cout);
        {A, B, Cin} = 3'b101; #10; // 1+0+1
        $display("%b %b  %b  |  %b    %b", A, B, Cin, Sum, Cout);
        {A, B, Cin} = 3'b110; #10; // 1+1+0
        $display("%b %b  %b  |  %b    %b", A, B, Cin, Sum, Cout);
        {A, B, Cin} = 3'b111; #10; // 1+1+1
        $display("%b %b  %b  |  %b    %b", A, B, Cin, Sum, Cout);
        $finish;
    end
endmodule