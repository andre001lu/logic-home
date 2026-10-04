// This is a basic Flutter widget test for the Logic Home SaaS.
// Ele verifica se o ambiente de testes está saudável ignorando a inicialização do Firebase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Logic Home SaaS - Smoke test inicial (Isolado do Firebase)', (WidgetTester tester) async {
    
    // Constrói um widget isolado para garantir que a renderização 
    // do Flutter não está quebrando antes de tentar acessar a nuvem.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Ambiente de Teste Saudável'),
        ),
      ),
    );

    // Aguarda a renderização
    await tester.pumpAndSettle();

    // Verifica se a tela renderizou sem crashar
    expect(find.text('Ambiente de Teste Saudável'), findsOneWidget);
  });
}