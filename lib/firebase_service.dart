import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseService {
  static Future<Map<String, dynamic>> criarUsuarioSaaS({
    required String email,
    required String senha,
    required String nome,
    required String perfil,
    String? codigoValidacao, // NOVO CAMPO: O PIN agora viaja para a nuvem
    String? condominio,
    String? idCondominio,
    String? planoId,
    DateTime? dataExpiracao,
    bool? servicoAtivo,
    bool exigeTrocaSenha = false,
    String? sindicoVinculado,
    String? telefone,
    String? bloco,
    String? ap,
    bool? emailVerificado,
    bool? aceitouTermos,
  }) async {
    try {
      // 1. Pegamos o "crachá" (Token) de quem está logado (Master ou Síndico)
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null ? await user.getIdToken() : '';

      // 2. Montamos o pacote de dados EXATAMENTE como a função "onCall" do seu backend espera
      final Map<String, dynamic> payloadData = {
        'email': email,
        'senha': senha,
        'nome': nome,
        'perfil': perfil,
        'codigo_validacao': ?codigoValidacao, 
        'condominio': ?condominio,
        'id_condominio': ?idCondominio,
        'plano_id': ?planoId,
        if (dataExpiracao != null) 'data_expiracao': dataExpiracao.toIso8601String(),
        'servico_ativo': ?servicoAtivo,
        'exige_troca_senha': exigeTrocaSenha,
        'sindico_vinculado': ?sindicoVinculado,
        'telefone': ?telefone,
        'bloco': ?bloco,
        'ap': ?ap,
        'email_verificado': ?emailVerificado,
        'aceitou_termos': ?aceitouTermos,
      };

      // 3. O Link Universal para o seu backend no Firebase
      final url = Uri.parse('https://us-central1-logichome-a9808.cloudfunctions.net/criarUsuarioSaaS');

      // 4. Enviamos usando a transportadora universal HTTP
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'data': payloadData}),
      );

      // 5. Tratamento das respostas da transportadora
      if (response.statusCode == 200) {
        // Sucesso absoluto
        final responseBody = jsonDecode(response.body);
        return {'sucesso': true, 'data': responseBody['result'] ?? responseBody};
      } else {
        // Erros enviados pelo backend (ex: email já existe, permissão negada, PIN incorreto)
        var errorMsg = 'Erro do Servidor HTTP ${response.statusCode}';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody['error'] != null && errorBody['error']['message'] != null) {
            errorMsg = errorBody['error']['message'];
          }
        } catch (_) {}
        return {'sucesso': false, 'erro': errorMsg};
      }

    } catch (e) {
      // Erro caso caia a internet do usuário bem na hora de clicar
      return {'sucesso': false, 'erro': 'Falha na conexão: $e'};
    }
  }

  // =======================================================================
  // NOVA FUNÇÃO: SISTEMA KMS (Via HTTP Direto - Bypass Windows)
  // =======================================================================
  static Future<String?> obterChaveAESDaNuvem() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null ? await user.getIdToken(true) : '';

      // Chama a nuvem diretamente usando a estrada principal da internet (HTTP)
      final url = Uri.parse('https://us-central1-logichome-a9808.cloudfunctions.net/obterChaveSeguranca');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'data': {}}), // Funções "onCall" sempre precisam de um "data" na raiz.
      );

      if (response.statusCode == 200) {
        final bodyDecoded = jsonDecode(response.body);
        final responseData = bodyDecoded['result'] ?? bodyDecoded['data'];

        if (responseData != null && responseData['sucesso'] == true) {
          return responseData['chave'];
        }
      } else {
        print("❌ ERRO NO COFRE (HTTP): Resposta ${response.statusCode} - ${response.body}");
      }
      return null;
    } catch (e) {
      print("❌ ERRO NO COFRE (CATCH): $e"); 
      return null; 
    }
  }

  // Mantive sua função de Storage 100% intacta
  static Future<String?> uploadArquivo(String path, Uint8List bytes) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putData(bytes, metadata);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }
}