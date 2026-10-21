// ignore_for_file: use_build_context_synchronously, curly_braces_in_flow_control_structures, avoid_print, use_null_aware_elements, prefer_final_fields, avoid_types_as_parameter_names, unnecessary_cast, unnecessary_const, unnecessary_underscores, empty_catches

// ============================================================================
// PARTE 1 - CONFIGURAÇÕES GERAIS E COMPONENTES VISUAIS (CORE)
// ============================================================================
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; 
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart'; 
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter/foundation.dart'; 
import 'package:mobile_scanner/mobile_scanner.dart'; 
import 'package:image_picker/image_picker.dart'; 
import 'package:share_plus/share_plus.dart';
import 'package:camera/camera.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:screen_protector/screen_protector.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as img; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'firebase_options.dart';
import 'firebase_service.dart';
import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:ui';

String operadorLogado = "Desconhecido";
String pulseiraDaSessao = ""; 
String urlTunelVideoAtiva = ""; 

class TelaMudarSenhaForcada extends StatefulWidget {
  final String email;
  final Map<String, dynamic> userData;
  const TelaMudarSenhaForcada({super.key, required this.email, required this.userData});

  @override
  State<TelaMudarSenhaForcada> createState() => _TelaMudarSenhaForcadaState();
}

class _TelaMudarSenhaForcadaState extends State<TelaMudarSenhaForcada> {
  final TextEditingController _novaSenha = TextEditingController();
  final TextEditingController _confirmaSenha = TextEditingController();
  
  bool _ocultarNovaSenha = true;
  bool _ocultarConfirmaSenha = true;

  void _salvarNovaSenha() async {
    if (_novaSenha.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("A senha deve ter pelo menos 6 caracteres.", style: TextStyle(color: Theme.of(context).colorScheme.onError)), backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }
    if (_novaSenha.text != _confirmaSenha.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("As senhas não coincidem.", style: TextStyle(color: Theme.of(context).colorScheme.onError)), backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }

    try {
      await FirebaseAuth.instance.currentUser!.updatePassword(_novaSenha.text);
      await FirebaseFirestore.instance.collection('usuarios').doc(widget.email).update({'exige_troca_senha': false});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Senha atualizada com sucesso!"), backgroundColor: Colors.green));
      _redirecionarAposLogin(widget.email, widget.userData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e), style: TextStyle(color: Theme.of(context).colorScheme.onError)), backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  void _redirecionarAposLogin(String email, Map<String, dynamic> data) async {
    if (data['perfil'] == 'master') {
      operadorLogado = data['nome'] ?? "Equipe Master";
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PainelDev()));
      return;
    }
    if (data['perfil'] == 'tecnico') {
      operadorLogado = data['nome'] ?? email;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaSelecaoCondominioTecnico()));
      return;
    }
    if (data['perfil'] == 'administradora') {
      operadorLogado = data['nome'] ?? email;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaMeusCondominios()));
      return;
    }
    if (data['perfil'] == 'sindico') {
      List<dynamic> gerenciados = data['condominios_gerenciados'] ?? [];
      if (gerenciados.isNotEmpty) {
        operadorLogado = data['nome'] ?? email;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaMeusCondominios()));
        return;
      }
    }
    String sRef = (data['perfil'] == 'sindico') ? email : (data['sindico_vinculado'] ?? "");
    Map<String, dynamic> funcionalidadesPlano = {};
    if (sRef.isNotEmpty) {
      var sDoc = await FirebaseFirestore.instance.collection('usuarios').doc(sRef).get();
      if (sDoc.exists) {
        var sData = sDoc.data()!;
        if (sData.containsKey('plano_id') && sData['plano_id'].toString().isNotEmpty) {
          var planoDoc = await FirebaseFirestore.instance.collection('planos').doc(sData['plano_id']).get();
          if (planoDoc.exists) funcionalidadesPlano = planoDoc.data()?['funcionalidades'] ?? {};
        }
      }
    }
    if (!mounted) return;
    if (data['perfil'] == 'morador') {
      operadorLogado = data['nome'] ?? email;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaMorador(userData: data)));
    } else {
      operadorLogado = data['nome'] ?? email;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PainelEstrutural(perfil: data['perfil'], emailSindico: sRef, funcionalidadesPermitidas: funcionalidadesPlano, menusPersonalizados: data['menus_personalizados'] ?? {})));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Atualização de Segurança"), automaticallyImplyLeading: false, actions: const [BotaoTrocarTema()]),
      body: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            width: 350, padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children:[
                Icon(Icons.lock_reset, size: 80, color: colorScheme.secondary), const SizedBox(height: 20),
                const Text("Por questões de segurança, você precisa definir uma nova senha pessoal.", textAlign: TextAlign.center), const SizedBox(height: 20),
                TextField(controller: _novaSenha, obscureText: _ocultarNovaSenha, decoration: InputDecoration(labelText: "Nova Senha (Mín. 6 caracteres)", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_ocultarNovaSenha ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ocultarNovaSenha = !_ocultarNovaSenha)))), const SizedBox(height: 15),
                TextField(controller: _confirmaSenha, obscureText: _ocultarConfirmaSenha, decoration: InputDecoration(labelText: "Confirme a Nova Senha", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_ocultarConfirmaSenha ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ocultarConfirmaSenha = !_ocultarConfirmaSenha)))), const SizedBox(height: 20),
                ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: _salvarNovaSenha, child: const Text("SALVAR E CONTINUAR"))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TelaMoradorOffline extends StatefulWidget {
  final Map<String, dynamic> userData;
  const TelaMoradorOffline({super.key, required this.userData});
  @override
  State<TelaMoradorOffline> createState() => _TelaMoradorOfflineState();
}

class _TelaMoradorOfflineState extends State<TelaMoradorOffline> {
  List<dynamic> _portoes = []; Timer? _internetMonitorTimer;

  @override
  void initState() {
    super.initState(); _carregarPortoesDoCofre();
    _internetMonitorTimer = Timer.periodic(const Duration(seconds: 5), (_) => _verificarSeAInternetVoltou());
  }

  Future<void> _verificarSeAInternetVoltou() async {
    // Ignora o teste se o aplicativo estiver minimizado para não dar falso positivo por economia de bateria
    if (WidgetsBinding.instance.lifecycleState != null && WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;

    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (mounted) {
          _internetMonitorTimer?.cancel();
          try {
            await FirebaseAuth.instance.currentUser?.reload();
            User? user = FirebaseAuth.instance.currentUser;
            if (user == null) throw Exception("Sessão expirada");
            var docUser = await FirebaseFirestore.instance.collection('usuarios').doc(user.email).get(const GetOptions(source: Source.server));
            if (!docUser.exists) throw Exception("Usuário removido");
            var data = docUser.data()!;
            if (data['status'] != 'aprovado' || data['servico_ativo'] != true) throw Exception("Acesso bloqueado");
            if (mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaMorador(userData: data)));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Internet restabelecida! Você está online novamente."), backgroundColor: Colors.green));
            }
          } catch (e) {
            await FirebaseAuth.instance.signOut();
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('off_user_data'); await prefs.remove('off_senha');
            if (globalNavigatorKey.currentContext != null) {
              Navigator.pushAndRemoveUntil(globalNavigatorKey.currentContext!, MaterialPageRoute(builder: (context) => const TelaLogin()), (route) => false);
              showDialog(context: globalNavigatorKey.currentContext!, barrierDismissible: false, builder: (c) => AlertDialog(title: const Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 10), Text("Acesso Negado")]), content: const Text("Seu acesso foi revogado ou alterado pela administração. Entre em contato com a Portaria/Síndico."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("FECHAR"))]));
            }
          }
        }
      }
    } catch (_) {}
  }
  
  @override
  void dispose() { _internetMonitorTimer?.cancel(); super.dispose(); }

  Future<void> _carregarPortoesDoCofre() async {
    final prefs = await SharedPreferences.getInstance();
    String? portoesStr = prefs.getString('off_portoes');
    if (portoesStr != null) setState(() => _portoes = jsonDecode(portoesStr));
  }

  Future<void> _abrirViaBluetooth(String macApp, String rele) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) { await Permission.bluetoothScan.request(); await Permission.bluetoothConnect.request(); await Permission.locationWhenInUse.request(); }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aguarde..."), duration: Duration(seconds: 2)));
      await Future.delayed(const Duration(milliseconds: 200));
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        if (defaultTargetPlatform == TargetPlatform.android) try { await FlutterBluePlus.turnOn(); } catch (_) {}
        try { await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first.timeout(const Duration(seconds: 5)); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ative o Bluetooth para abrir o portão!"), backgroundColor: Colors.orange)); return; }
      }
      try { if (await FlutterBluePlus.isScanning.first) await FlutterBluePlus.stopScan(); } catch(e){}
      await Future.delayed(const Duration(milliseconds: 500));

      Completer<bool> completer = Completer<bool>(); StreamSubscription? subscription; bool conectando = false;

      subscription = FlutterBluePlus.scanResults.listen((results) async {
        if (conectando) return;
        for (ScanResult r in results) {
          String nome = r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName;
          bool achouPeloUUID = r.advertisementData.serviceUuids.any((uuid) => uuid.toString().toLowerCase() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b");
          if (nome.contains("PORTAO") || achouPeloUUID) {
            conectando = true; try { await FlutterBluePlus.stopScan(); } catch(e){} 
            try {
              await r.device.connect(timeout: const Duration(seconds: 10), autoConnect: false);
              await Future.delayed(const Duration(milliseconds: 500));
              List<BluetoothService> services = await r.device.discoverServices();
              for (var service in services) {
                if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
                  for (var c in service.characteristics) {
                    if (c.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
                      await c.setNotifyValue(true);
                      String meuEmail = widget.userData['email'] ?? '';
                      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
                      String pacoteCripto = Uri.encodeComponent(CryptoHelper.criptografar("$meuEmail;$timestamp;OFF")); 
                      String comandoSeguro = "SEC|$pacoteCripto|$rele";
                      
                      bool resolvido = false; StreamSubscription? notifySub;
                      notifySub = c.onValueReceived.listen((value) async {
                        String rep = utf8.decode(value);
                        if (rep == "OK") { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Portão abrindo"), backgroundColor: Colors.green)); resolvido = true; } 
                        else if (rep == "BLKD") {
                          resolvido = true;
                          if (globalNavigatorKey.currentContext != null) {
                            final prefs = await SharedPreferences.getInstance(); await prefs.remove('off_user_data'); await prefs.remove('off_senha'); await FirebaseAuth.instance.signOut();
                            Navigator.pushAndRemoveUntil(globalNavigatorKey.currentContext!, MaterialPageRoute(builder: (context) => const TelaLogin()), (route) => false);
                            showDialog(context: globalNavigatorKey.currentContext!, barrierDismissible: false, builder: (c) => AlertDialog(title: const Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 10), Text("Acesso Negado")]), content: const Text("Você não tem permissão da administração para abrir o portão. Entre em contato com a Portaria para resolver."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("FECHAR"))]));
                          }
                        } else if (rep == "ERR") { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Falha ao comunicar com o portão."), backgroundColor: Colors.orange)); resolvido = true; } 
                        else if (rep == "MOV") { resolvido = true; if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), backgroundColor: Colors.orange.shade800, content: const Row(children: [Icon(Icons.warning, color: Colors.white), SizedBox(width: 10), Expanded(child: Text("Aguarde! Portão já está em movimento.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]))); }
                      });

                      await c.write(utf8.encode(comandoSeguro), withoutResponse: false);
                      for (int i = 0; i < 15; i++) { await Future.delayed(const Duration(milliseconds: 500)); if (resolvido) break; }
                      notifySub.cancel(); await r.device.disconnect();
                      if (!completer.isCompleted) completer.complete(resolvido);
                      return;
                    }
                  }
                }
              }
              await r.device.disconnect();
            } catch (e) { debugPrint("Erro na placa: $e"); }
            if (!completer.isCompleted) completer.complete(false);
            return;
          }
        }
      });

      try { await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6)); } catch (e) {}
      bool resultado = await completer.future.timeout(const Duration(seconds: 8), onTimeout: () => false);
      subscription.cancel(); try { await FlutterBluePlus.stopScan(); } catch(e){}
      if (!resultado && !conectando && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Portão não encontrado. Aproxime-se mais!"), backgroundColor: Colors.red));
    } catch (e) { debugPrint("Erro Bluetooth: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Logic Home OFFLINE"), backgroundColor: Colors.red.shade900, actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaLogin())); })]),
      body: Column(
        children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(15), color: Colors.red.shade900, child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.wifi_off, color: Colors.white), SizedBox(width: 10), Text("MODO DE EMERGÊNCIA (BLUETOOTH)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),
          const Padding(padding: EdgeInsets.all(20.0), child: Text("O aplicativo está sem internet. O sistema foi bloqueado por segurança, mas você ainda pode abrir os portões via Bluetooth diretamente na placa.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.white70))),
          Expanded(
            child: _portoes.isEmpty ? const Center(child: Text("Nenhum portão salvo no modo offline.", style: TextStyle(color: Colors.white))) : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _portoes.length,
              itemBuilder: (context, i) {
                var data = _portoes[i] as Map<String, dynamic>;
                return Card(margin: const EdgeInsets.only(bottom: 15), shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.blue, width: 2), borderRadius: BorderRadius.circular(15)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.bluetooth, color: Colors.white)), title: Text(data['nome'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white), onPressed: () => _abrirViaBluetooth(data['id_box'], data['codigo']), child: const Text("ABRIR", style: TextStyle(fontWeight: FontWeight.bold)))));
              }
            )
          )
        ],
      ),
    );
  }
}

class TelaLogin extends StatefulWidget {
  final bool redirecionarParaAproximacao;
  final bool redirecionarParaAvisos;
  final bool redirecionarParaEncomendas;
  final bool redirecionarParaFaturas;
  final bool redirecionarParaReservas;
  const TelaLogin({super.key, this.redirecionarParaAproximacao = false, this.redirecionarParaAvisos = false, this.redirecionarParaEncomendas = false, this.redirecionarParaFaturas = false, this.redirecionarParaReservas = false});
  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();
  bool _carregando = false, _lembrarMe = true, _ocultarSenha = true, _verificandoSessaoInicial = false;

  @override
  void initState() {
    super.initState();
    if (FirebaseAuth.instance.currentUser != null) _verificandoSessaoInicial = true;
    else _verificandoSessaoInicial = false;
    WidgetsBinding.instance.addPostFrameCallback((_) { _verificarSessaoAtiva(); });
  }

  void _verificarSessaoAtiva() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _carregando = true);
      try {
        var userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.email).get(const GetOptions(source: Source.cache));
        if (userDoc.exists) {
          var cacheData = userDoc.data()!;
          bool aprovadoMorador = cacheData['perfil'] == 'morador' && (cacheData['status'] == 'aprovado' || cacheData['servico_ativo'] == true);
          bool aprovadoGeral = cacheData['perfil'] != 'morador';
          if (aprovadoMorador || aprovadoGeral) { _rotearUsuario(user.email!, cacheData, loginManual: false); return; }
        }
      } catch (_) {}
      
      bool temInternet = true;
      if (!kIsWeb) {
        try { final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3)); if (result.isEmpty || result[0].rawAddress.isEmpty) temInternet = false; } catch (_) { temInternet = false; }
      }

      if (!temInternet) {
        final prefs = await SharedPreferences.getInstance();
        String offEmail = prefs.getString('off_email') ?? '', offDataStr = prefs.getString('off_user_data') ?? '', offTimestamp = prefs.getString('off_ultimo_login') ?? '';
        if (offEmail == user.email && offDataStr.isNotEmpty) {
          DateTime ultimoLogin = DateTime.parse(offTimestamp);
          if (DateTime.now().difference(ultimoLogin).inHours < 168) {
            Map<String, dynamic> userData = jsonDecode(offDataStr);
            await HelperOffline.carregarChaveCofre(); 
            if (mounted) {
              if (widget.redirecionarParaAproximacao) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaAberturaPorAproximacao(userData: userData)));
              else Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaMoradorOffline(userData: userData)));
            }
            return;
          }
        }
        if (mounted) setState(() { _carregando = false; _verificandoSessaoInicial = false; });
        return;
      }

      try {
        var userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.email).get();
        if (userDoc.exists) {
          var userData = userDoc.data()!;
          if (userData['perfil'] == 'morador') {
             final prefs = await SharedPreferences.getInstance();
             String senhaSalva = prefs.getString('off_senha') ?? '';
             await HelperOffline.salvarNoCofre(user.email!, senhaSalva, userData);
             await HelperOffline.registrarUltimoAcessoOffline();
          }
          _rotearUsuario(user.email!, userData, loginManual: false);
        } else {
          if (mounted) setState(() { _carregando = false; _verificandoSessaoInicial = false; });
          await FirebaseAuth.instance.signOut();
        }
      } catch (e) { if (mounted) setState(() { _carregando = false; _verificandoSessaoInicial = false; }); }
    } else { if (mounted) setState(() => _verificandoSessaoInicial = false); }
  }

  @override
  void dispose() { _userController.dispose(); _senhaController.dispose(); super.dispose(); }

  void _mostrarAvisoExpiracao(String mensagem, VoidCallback aoConfirmar) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(title: Row(children:[Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.secondary), const SizedBox(width: 10), const Flexible(child: Text("Aviso de Licença"))]), content: Text(mensagem, style: const TextStyle(fontSize: 16)), actions:[ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary), onPressed: () { Navigator.pop(ctx); aoConfirmar(); }, child: const Text("CONTINUAR"))]));
  }

  void _recuperarSenha() async {
    String emailDigitado = _userController.text.trim().toLowerCase();
    if (emailDigitado.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Digite seu e-mail no campo acima primeiro."))); return; }
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Recuperação de Senha"), content: Text("Deseja receber um link oficial de redefinição de senha no e-mail $emailDigitado?"), actions:[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary), onPressed: () async { Navigator.pop(ctx); try { final urlValidacao = Uri.parse('https://us-central1-logichome-a9808.cloudfunctions.net/validarEmailReset'); final resVal = await http.post(urlValidacao, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'data': {'email': emailDigitado}})); if (resVal.statusCode != 200) throw Exception("E-mail não encontrado no sistema ou não autorizado."); if (!mounted) return; if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) { String apiKey = DefaultFirebaseOptions.windows.apiKey; final url = Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey'); final response = await http.post(url, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'requestType': 'PASSWORD_RESET', 'email': emailDigitado})); if (response.statusCode != 200) throw Exception("Falha de conexão com os servidores do Google."); } else { await FirebaseAuth.instance.sendPasswordResetEmail(email: emailDigitado); } ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link de recuperação enviado! Verifique sua caixa de entrada e Spam."), backgroundColor: Colors.green, duration: Duration(seconds: 5))); } catch (e) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e), style: TextStyle(color: Theme.of(context).colorScheme.onError)), backgroundColor: Theme.of(context).colorScheme.error)); } }, child: const Text("ENVIAR LINK"))]));
  }

  void _entrar() async {
    String u = _userController.text.trim().toLowerCase(), s = _senhaController.text.trim();
    if (u.isEmpty || s.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos."), backgroundColor: Colors.red)); return; }
    setState(() => _carregando = true);
    bool temInternet = true;
    // Pula o teste de Ping se for WEB, pois o navegador bloqueia o InternetAddress.lookup
    if (!kIsWeb) {
      try { final result = await InternetAddress.lookup('google.com'); if (result.isEmpty || result[0].rawAddress.isEmpty) temInternet = false; } catch (_) { temInternet = false; }
    }

    if (!temInternet) {
      final prefs = await SharedPreferences.getInstance(); const cofreSeguro = FlutterSecureStorage();
      String offEmail = prefs.getString('off_email') ?? '', offSenha = await cofreSeguro.read(key: 'off_senha') ?? '', offDataStr = prefs.getString('off_user_data') ?? '', offTimestamp = prefs.getString('off_ultimo_login') ?? '';
      if (offEmail.isEmpty || offDataStr.isEmpty) { if (!mounted) return; setState(() => _carregando = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Primeiro acesso. Conecte-se à internet pelo menos uma vez para salvar seus dados."), backgroundColor: Colors.orange)); return; }
      if (offEmail != u || offSenha != s) { if (!mounted) return; setState(() => _carregando = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("E-mail ou senha incorretos."), backgroundColor: Colors.red)); return; }
      DateTime ultimoLogin = DateTime.parse(offTimestamp);
      if (DateTime.now().difference(ultimoLogin).inHours < 168) {
        Map<String, dynamic> userData = jsonDecode(offDataStr);
        await HelperOffline.carregarChaveCofre();
        if (!mounted) return;
        if (widget.redirecionarParaAproximacao) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaAberturaPorAproximacao(userData: userData))); else Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaMoradorOffline(userData: userData)));
        return;
      } else { if (!mounted) return; setState(() => _carregando = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Por segurança, após 7 dias offline, conecte-se à internet pelo menos uma vez para renovar o acesso."), backgroundColor: Colors.orange)); return; }
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: u, password: s);
      var userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(u).get();
      if (!mounted) return;
      if (userDoc.exists) {
        var userData = userDoc.data()!;
        if (userData['perfil'] == 'morador') { await HelperOffline.salvarNoCofre(u, s, userData); await HelperOffline.registrarUltimoAcessoOffline(); }
        _rotearUsuario(u, userData, loginManual: true);
      } else {
        setState(() => _carregando = false); await FirebaseAuth.instance.signOut(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Usuário não configurado no banco de dados."), backgroundColor: Colors.red));
      }
    } catch (e) { if (!mounted) return; setState(() => _carregando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); }
  }

  void _rotearUsuario(String u, Map<String, dynamic> data, {bool loginManual = false}) async {
    try {
      if (!mounted) return;
      if (loginManual) await Future.delayed(const Duration(milliseconds: 150));
      try {
        await FirebaseAuth.instance.currentUser?.getIdToken(true);
        String? chaveMestra = await FirebaseService.obterChaveAESDaNuvem();
        if (chaveMestra != null && chaveMestra.isNotEmpty) { CryptoHelper.inicializarCofre(chaveMestra); await HelperOffline.salvarChaveCofre(chaveMestra); }
      } catch (e) { debugPrint("⚠️ Sem internet no Boot. Entrando no modo Offline..."); }

      if (data['exige_troca_senha'] == true) { setState(() { _carregando = false; _verificandoSessaoInicial = false; }); Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => TelaMudarSenhaForcada(email: u, userData: data))); return; }

      bool isMoradorPendente = data['perfil'] == 'morador' && (data['servico_ativo'] != true && data['status'] != 'aprovado');
      if (!isMoradorPendente) {
        pulseiraDaSessao = const Uuid().v4(); 
        List<dynamic> sessoesAtivas = data['sessoes_ativas'] ?? []; sessoesAtivas.add(pulseiraDaSessao);
        await FirebaseFirestore.instance.collection('usuarios').doc(u).update({'sessoes_ativas': sessoesAtivas});
      }

      if (data['perfil'] != 'morador') { await HelperOffline.limparCofre(); }

      if (data['perfil'] == 'master') { operadorLogado = data['nome'] ?? "Equipe Master"; if (!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PainelDev())); return; }
      if (data['perfil'] == 'tecnico') { operadorLogado = data['nome'] ?? u; if (!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaSelecaoCondominioTecnico())); return; }
      if (data['perfil'] == 'administradora') { setState(() => _carregando = false); operadorLogado = data['nome'] ?? u; Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaMeusCondominios())); return; }
      if (data['perfil'] == 'sindico') { List<dynamic> gerenciados = data['condominios_gerenciados'] ?? []; if (gerenciados.isNotEmpty) { setState(() => _carregando = false); operadorLogado = data['nome'] ?? u; Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaMeusCondominios())); return; } }

      String sRef = (data['perfil'] == 'sindico') ? u : (data['sindico_vinculado'] ?? "");
      int diasRestantes = 999; Map<String, dynamic> funcionalidadesPlano = {};

      if (sRef.isNotEmpty) {
        var sDoc = await FirebaseFirestore.instance.collection('usuarios').doc(sRef).get();
        if (!mounted) return;
        bool sindicoAtivo = sDoc.exists && (sDoc.data()?['servico_ativo'] == true);
        if (!sindicoAtivo || !sDoc.exists) { setState(() { _carregando = false; _verificandoSessaoInicial = false; }); await FirebaseAuth.instance.signOut(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("O acesso deste condomínio está suspenso, expirado ou foi removido.", style: TextStyle(color: Theme.of(context).colorScheme.onError)), backgroundColor: Theme.of(context).colorScheme.error)); return; }
        var sData = sDoc.data()!;
        if (sData.containsKey('data_expiracao') && sData['data_expiracao'] != null) { DateTime dataExp = (sData['data_expiracao'] as Timestamp).toDate(); diasRestantes = dataExp.difference(DateTime.now()).inDays; }
        if (sData.containsKey('plano_id') && sData['plano_id'].toString().isNotEmpty) { var planoDoc = await FirebaseFirestore.instance.collection('planos').doc(sData['plano_id']).get(); if (planoDoc.exists) funcionalidadesPlano = planoDoc.data()?['funcionalidades'] ?? {}; }
      }

      void prosseguirLogin() {
        if (!mounted) return;
        setState(() => _carregando = false);
        Widget telaDestino;
        if (data['perfil'] == 'morador') {
          operadorLogado = "${data['nome'] ?? u} (B: ${data['bloco'] ?? '-'} AP: ${data['ap'] ?? '-'})";
          bool aprovado = data['servico_ativo'] == true || data['status'] == 'aprovado';
          if (!aprovado) { telaDestino = TelaMorador(userData: data); } else if (widget.redirecionarParaAproximacao) { telaDestino = TelaAberturaPorAproximacao(userData: data); } else if (widget.redirecionarParaAvisos) { telaDestino = TelaMorador(userData: data, abaInicial: 6); } else if (widget.redirecionarParaEncomendas) { telaDestino = TelaMorador(userData: data, abaInicial: 2); } else if (widget.redirecionarParaFaturas) { telaDestino = TelaMorador(userData: data, abaInicial: 5); } else if (widget.redirecionarParaReservas) { telaDestino = TelaMorador(userData: data, abaInicial: 3); } else { telaDestino = TelaMorador(userData: data); }
        } else {
          operadorLogado = data['nome'] ?? u;
          if (widget.redirecionarParaAvisos) { telaDestino = TelaNotificacoes(perfil: data['perfil'], emailSindico: sRef, emailUsuario: u); } else { telaDestino = PainelEstrutural(perfil: data['perfil'], emailSindico: sRef, funcionalidadesPermitidas: funcionalidadesPlano, menusPersonalizados: data['menus_personalizados'] ?? {}); }
        }
        if (widget.redirecionarParaAproximacao || widget.redirecionarParaAvisos || widget.redirecionarParaEncomendas || widget.redirecionarParaFaturas || widget.redirecionarParaReservas || !loginManual) { Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (context, animation, secondaryAnimation) => telaDestino, transitionDuration: Duration.zero)); } else { Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (context, animation, secondaryAnimation) => TelaCarregamentoAnimado(proximaTela: telaDestino), transitionDuration: Duration.zero)); }
      }

      if ((data['perfil'] == 'sindico' || data['perfil'] == 'porteiro') && diasRestantes <= 7) { setState(() => _carregando = false); _mostrarAvisoExpiracao("Gostando da ajuda? Não esqueça de renovar a licença!\n\nSua licença expira em $diasRestantes dia(s).", prosseguirLogin); } else { prosseguirLogin(); }
    } catch (e) { if (!mounted) return; setState(() { _carregando = false; _verificandoSessaoInicial = false; }); await FirebaseAuth.instance.signOut(); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao processar login: $e", style: TextStyle(color: Theme.of(context).colorScheme.onError)), backgroundColor: Theme.of(context).colorScheme.error)); }
  }

  @override
  Widget build(BuildContext context) {
    if (_verificandoSessaoInicial) return Scaffold(backgroundColor: themeNotifier.isNeonTheme ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor);
    final colorScheme = Theme.of(context).colorScheme;
    final bool isNeon = themeNotifier.isNeonTheme;

    return Scaffold(
      appBar: AppBar(actions: const[BotaoTrocarTema()]),
      body: Center(
        child: SingleChildScrollView(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              width: 350, padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: isNeon ? const Color(0xFF0D111C).withValues(alpha:0.7) : colorScheme.surface.withValues(alpha:0.95), borderRadius: BorderRadius.circular(20), border: Border.all(color: colorScheme.primary.withValues(alpha:0.3)), boxShadow: [BoxShadow(color: isNeon ? Colors.black87 : colorScheme.shadow.withValues(alpha:0.2), blurRadius: 40, offset: const Offset(0, 20))]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children:[
                  const LogoLogicHome(size: 100), const SizedBox(height: 5), Text("SaaS Control Panel", style: TextStyle(color: colorScheme.onSurfaceVariant, letterSpacing: 2)), const SizedBox(height: 30),
                  TextField(controller: _userController, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: "E-mail", border: OutlineInputBorder())), const SizedBox(height: 15),
                  TextField(controller: _senhaController, obscureText: _ocultarSenha, textInputAction: TextInputAction.done, onSubmitted: (_) => _entrar(), decoration: InputDecoration(labelText: "Senha", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_ocultarSenha ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha)))),
                  CheckboxListTile(title: const Text("Mantenha-me conectado", style: TextStyle(fontSize: 14)), value: _lembrarMe, activeColor: colorScheme.primary, onChanged: (v) => setState(() => _lembrarMe = v!), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero),
                  Align(alignment: Alignment.centerRight, child: FittedBox(fit: BoxFit.scaleDown, child: TextButton(onPressed: _recuperarSenha, child: Text("Esqueci minha senha", style: TextStyle(color: colorScheme.primary))))), const SizedBox(height: 15),
                  _carregando ? const CircularProgressIndicator() : LogicNeonButton(fullWidth: true, corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: _entrar, child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.login, size: 18, color: Colors.white), SizedBox(width: 8), Text("ENTRAR", style: TextStyle(color: Colors.white))])), const SizedBox(height: 20),
                  Wrap(alignment: WrapAlignment.center, children:[TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaCadastroSindico())), child: Text("Novo Condomínio", style: TextStyle(color: colorScheme.primary))), TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaCadastroMorador())), child: Text("Sou Morador", style: TextStyle(color: colorScheme.primary)))])
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TelaMeusCondominios extends StatefulWidget {
  const TelaMeusCondominios({super.key});
  @override
  State<TelaMeusCondominios> createState() => _TelaMeusCondominiosState();
}

class _TelaMeusCondominiosState extends State<TelaMeusCondominios> {
  String busca = ""; List<dynamic> _meusCondominiosEmails = []; bool _carregando = true;

  @override
  void initState() { super.initState(); _carregarMeusCondominios(); }

  void _carregarMeusCondominios() async {
    String emailLogado = FirebaseAuth.instance.currentUser!.email!;
    var myDoc = await FirebaseFirestore.instance.collection('usuarios').doc(emailLogado).get();
    if (myDoc.exists) { if (mounted) { setState(() { _meusCondominiosEmails = myDoc.data()?['condominios_gerenciados'] ?? []; _carregando = false; }); } }
  }

  void _acessarCondominio(String emailCondominio) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
    try {
      var sDoc = await FirebaseFirestore.instance.collection('usuarios').doc(emailCondominio).get();
      if (!sDoc.exists) { if (!mounted) return; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acesso suspenso ou condomínio não encontrado."), backgroundColor: Colors.red)); return; }
      Map<String, dynamic> funcionalidadesPlano = {};
      if (sDoc.data()!.containsKey('plano_id')) { var planoDoc = await FirebaseFirestore.instance.collection('planos').doc(sDoc.data()!['plano_id']).get(); if (planoDoc.exists) funcionalidadesPlano = planoDoc.data()?['funcionalidades'] ?? {}; }
      if (!mounted) return; Navigator.pop(context); 
      var meuDoc = await FirebaseFirestore.instance.collection('usuarios').doc(FirebaseAuth.instance.currentUser!.email).get();
      Map<String, dynamic> menusPers = meuDoc.data()?['menus_personalizados'] ?? {};
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PainelEstrutural(perfil: 'sindico', emailSindico: emailCondominio, funcionalidadesPermitidas: funcionalidadesPlano, menusPersonalizados: menusPers, podeTrocarCondominio: true)));
    } catch (e) { if (!mounted) return; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)))); }
  }

  void _solicitarAcessoCondominio() {
    String emailAlvo = ""; bool enviando = false;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: Row(children:[Icon(Icons.handshake, color: colorScheme.primary), const SizedBox(width: 10), const Text("Solicitar Gestão")]), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Digite o E-mail de acesso do Síndico atual. O sistema enviará um pedido de autorização para ele.", style: TextStyle(fontSize: 13, color: Colors.grey)), const SizedBox(height: 15), TextField(onChanged: (v) => emailAlvo = v.trim().toLowerCase(), decoration: const InputDecoration(labelText: "E-mail do Condomínio (Síndico)", border: OutlineInputBorder()))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), enviando ? const CircularProgressIndicator() : ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async { if (emailAlvo.isEmpty) return; setStateSB(() => enviando = true); try { var docCondo = await FirebaseFirestore.instance.collection('usuarios').doc(emailAlvo).get(); if (!docCondo.exists || docCondo.data()?['perfil'] != 'sindico') { setStateSB(() => enviando = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Condomínio não encontrado!"), backgroundColor: Colors.red)); return; } await docCondo.reference.update({'pedido_administradora': {'email_admin': FirebaseAuth.instance.currentUser!.email, 'nome_admin': operadorLogado, 'data_pedido': FieldValue.serverTimestamp()}}); if (!mounted) return; Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pedido enviado! Aguarde o aceite do Síndico."), backgroundColor: Colors.green)); } catch (e) { setStateSB(() => enviando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); } }, child: const Text("ENVIAR PEDIDO"))]);
    }));
  }

  void _desvincularCondominio(String emailCondominio, String nomeCondominio) {
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: Text("Desvincular Condomínio", style: TextStyle(color: colorScheme.error)), content: Text("Tem certeza que deseja remover '$nomeCondominio' do seu painel?\n\nOs moradores não serão afetados, mas você perderá o acesso imediatamente. A gestão voltará a ser 100% do Síndico local."), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError), onPressed: () async { try { String meuEmail = FirebaseAuth.instance.currentUser!.email!; await FirebaseFirestore.instance.collection('usuarios').doc(meuEmail).update({'condominios_gerenciados': FieldValue.arrayRemove([emailCondominio])}); await FirebaseFirestore.instance.collection('usuarios').doc(emailCondominio).update({'administradora_vinculada': FieldValue.delete()}); if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Condomínio removido da sua lista com sucesso!"))); _carregarMeusCondominios(); } } catch (e) { if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: colorScheme.error)); } } }, child: const Text("SIM, DESVINCULAR"))]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Lobby da Administradora"), actions:[const BotaoTrocarTema(), IconButton(icon: const Icon(Icons.logout), onPressed: () async { await FirebaseAuth.instance.signOut(); if (!mounted) return; Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const TelaLogin())); })]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _solicitarAcessoCondominio, icon: const Icon(Icons.add_business), label: const Text("Vincular Condomínio")),
      body: _carregando ? const Center(child: CircularProgressIndicator()) : Column(children:[Padding(padding: const EdgeInsets.all(16.0), child: TextField(onChanged: (v) => setState(() => busca = v.toLowerCase()), decoration: const InputDecoration(labelText: "Buscar Condomínio", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('usuarios').where('perfil', isEqualTo: 'sindico').snapshots(), builder: (context, snap) { if (snap.hasError) return const Center(child: Text("Erro ao carregar dados.")); if (!snap.hasData) return const Center(child: CircularProgressIndicator()); var lista = snap.data!.docs.where((d) { if (!_meusCondominiosEmails.contains(d.id)) return false; var data = d.data() as Map<String, dynamic>; String c = (data['condominio'] ?? "").toString().toLowerCase(); return busca.isEmpty || c.contains(busca); }).toList(); if (lista.isEmpty) return const Center(child: Text("Nenhum condomínio vinculado a esta conta.")); return ListView.builder(padding: const EdgeInsets.all(16), itemCount: lista.length, itemBuilder: (context, index) { var doc = lista[index]; var data = doc.data() as Map<String, dynamic>; bool ativo = data['servico_ativo'] == true; String nomeCondo = data['condominio'] ?? "Sem Nome"; return Card(elevation: 3, margin: const EdgeInsets.only(bottom: 15), shape: RoundedRectangleBorder(side: BorderSide(color: ativo ? colorScheme.primary.withValues(alpha:0.3) : colorScheme.error), borderRadius: BorderRadius.circular(10)), child: ListTile(leading: CircleAvatar(backgroundColor: ativo ? colorScheme.primary : colorScheme.error, child: Icon(Icons.domain, color: ativo ? colorScheme.onPrimary : colorScheme.onError)), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(nomeCondo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))), subtitle: Text("ID: ${data['id_condominio']} | ${ativo ? 'Sistema Operante' : 'Acesso Suspenso'}"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [LogicNeonButton(corBase: ativo ? colorScheme.primary : Colors.orange.shade800, corBrilho: ativo ? colorScheme.primary : Colors.orangeAccent, onPressed: () => _acessarCondominio(doc.id), child: Text(ativo ? "GERENCIAR" : "DESBLOQUEAR", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), const SizedBox(width: 5), IconButton(icon: Icon(Icons.link_off, color: colorScheme.error), tooltip: "Desvincular Condomínio", onPressed: () => _desvincularCondominio(doc.id, nomeCondo))]))); }); }))]),
    );
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Notificação recebida em background: ${message.messageId}");

  if (message.data['eh_panico'] == "true") {
    await FlutterCallkitIncoming.showCallkitIncoming(CallKitParams(
      id: const Uuid().v4(),
      nameCaller: 'PÂNICO NA PORTARIA',
      appName: 'Logic Home',
      avatar: 'https://cdn-icons-png.flaticon.com/512/1008/1008928.png', 
      handle: 'Emergência!',
      type: 0,
      duration: 30000, 
      textAccept: 'VER CÂMERAS',
      textDecline: 'DESLIGAR',
      missedCallNotification: NotificationParams(showNotification: true, isShowCallback: false, subtitle: 'Pânico não atendido', callbackText: 'Ligar de volta'),
      extra: <String, dynamic>{'userId': '1a2b3c4d'},
      headers: <String, dynamic>{'apiKey': 'v1234567890'},
      android: const AndroidParams(
        isCustomNotification: true, isShowLogo: false, ringtonePath: 'sirene', backgroundColor: '#FF0000', actionColor: '#4CAF50', textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Emergência', missedCallNotificationChannelName: 'Emergência Perdida',
      ),
      ios: const IOSParams(iconName: 'CallKitLogo', handleType: 'generic', supportsVideo: true, maximumCallGroups: 2, maximumCallsPerCallGroup: 1, audioSessionMode: 'default', audioSessionActive: true, audioSessionPreferredSampleRate: 44100.0, audioSessionPreferredIOBufferDuration: 0.005, supportsDTMF: true, supportsHolding: true, supportsGrouping: false, supportsUngrouping: false, ringtonePath: 'sirene.mp3'),
    ));
  } else if (message.notification == null) {
    await FlutterLocalNotificationsPlugin().show(
      message.hashCode, 
      message.data['title'] ?? message.data['titulo'] ?? "Novo Aviso", 
      message.data['body'] ?? message.data['mensagem'] ?? "",
      const NotificationDetails(
        android: AndroidNotificationDetails('logic_home_channel', 'Avisos e Entregas', importance: Importance.max, priority: Priority.max, color: Color(0xFF00E5FF), playSound: true, enableVibration: true, visibility: NotificationVisibility.public),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: message.data['tipo_acao'] ?? 'acao_avisos',
    );
  }
}

Future<void> _redirecionarExpresso(String tipoAcao, BuildContext context) async {
  if (FirebaseAuth.instance.currentUser != null) {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(FirebaseAuth.instance.currentUser!.email).get();
      if (userDoc.exists) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => TelaMorador(userData: userDoc.data()!, abaInicial: 6)), (_) => false);
        return;
      }
    } catch (_) {}
  }
  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const TelaLogin(redirecionarParaAvisos: true)), (_) => false);
}

FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class GridBackground extends StatelessWidget {
  const GridBackground({super.key});
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFF030305), 
    child: kIsWeb ? null : CustomPaint(painter: _GridPainter(), child: Container()),
  );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.05)..strokeWidth = 1.0;
    for (double i = 0; i < size.width; i += 30.0) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i < size.height; i += 30.0) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LogicNeonButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color corBase;
  final Color corBrilho;
  final bool fullWidth;

  const LogicNeonButton({super.key, required this.onPressed, required this.child, this.corBase = const Color(0xFF0A2A66), this.corBrilho = const Color(0xFF00E5FF), this.fullWidth = false});

  @override
  State<LogicNeonButton> createState() => _LogicNeonButtonState();
}

class _LogicNeonButtonState extends State<LogicNeonButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    final scale = _isPressed ? (isMobile ? 0.85 : 0.96) : (!isMobile && _isHovered ? 1.02 : 1.0);
    final color1 = _isPressed && isMobile ? (Color.lerp(widget.corBase, Colors.white, 0.2) ?? widget.corBase) : (!isMobile && _isHovered ? (Color.lerp(widget.corBase, Colors.white, 0.1) ?? widget.corBase) : widget.corBase);
    final color2 = _isPressed && isMobile ? (Color.lerp(widget.corBase, widget.corBrilho, 0.6) ?? widget.corBrilho) : (!isMobile && _isHovered ? (Color.lerp(widget.corBase, widget.corBrilho, 0.5) ?? widget.corBrilho) : widget.corBase.withValues(alpha: 0.8));
    final borderColor = _isPressed && isMobile ? Colors.white : (!isMobile && _isHovered ? widget.corBrilho : widget.corBrilho.withValues(alpha: 0.5));
    final shadow1 = _isPressed ? (isMobile ? widget.corBrilho.withValues(alpha: 0.9) : widget.corBrilho.withValues(alpha: 0.6)) : (!isMobile && _isHovered ? Colors.black54 : widget.corBrilho.withValues(alpha: isMobile ? 0.2 : 0.1));
    final blur1 = kIsWeb ? 5.0 : (_isPressed ? (isMobile ? 20.0 : 10.0) : (!isMobile && _isHovered ? 20.0 : 15.0));
    final offset1 = (!isMobile && _isHovered && !_isPressed) ? const Offset(0, 10) : Offset.zero;
    final shadow2 = kIsWeb ? Colors.transparent : (_isPressed && isMobile ? widget.corBrilho.withValues(alpha: 0.6) : (!isMobile && _isHovered ? widget.corBrilho.withValues(alpha: 0.5) : Colors.transparent));
    final blur2 = kIsWeb ? 0.0 : (_isPressed && isMobile ? 40.0 : (!isMobile && _isHovered ? 20.0 : 0.0));
    final shadow3 = kIsWeb ? Colors.transparent : (!isMobile && _isHovered && !_isPressed ? widget.corBrilho.withValues(alpha: 0.2) : Colors.transparent);
    final blur3 = kIsWeb ? 0.0 : (!isMobile && _isHovered && !_isPressed ? 40.0 : 0.0);
    final duration = Duration(milliseconds: _isPressed ? 50 : 150);
    final curve = _isPressed ? Curves.easeOut : Curves.easeOutCubic;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) { if (isMobile) HapticFeedback.mediumImpact(); setState(() => _isPressed = true); },
        onTapUp: (_) async { setState(() => _isPressed = false); await Future.delayed(const Duration(milliseconds: 150)); if (mounted) widget.onPressed(); },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: scale, duration: duration, curve: curve,
          child: AnimatedContainer(
            duration: duration, curve: curve, width: widget.fullWidth ? double.infinity : null,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [color1, color2], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor), boxShadow: [BoxShadow(color: shadow1, blurRadius: blur1, offset: offset1), BoxShadow(color: shadow2, blurRadius: blur2), BoxShadow(color: shadow3, blurRadius: blur3)]),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2), textAlign: TextAlign.center, child: widget.child),
          ),
        ),
      ),
    );
  }
}

class AppConfig {
  static bool get isProduction => kReleaseMode;
  static String get urlAberturaPortao => 'https://us-central1-logichome-a9808.cloudfunctions.net/solicitarAberturaPortao'; 
  static String get googleWebClientId => kIsWeb ? 'SEU_WEB_CLIENT_ID_PARA_WEB.apps.googleusercontent.com' : (defaultTargetPlatform == TargetPlatform.windows ? 'SEU_WEB_CLIENT_ID_PARA_WINDOWS.apps.googleusercontent.com' : 'SEU_WEB_CLIENT_ID_PADRAO.apps.googleusercontent.com');
}

class CryptoHelper {
  static encrypt.Encrypter? _encrypter;
  static encrypt.Key? _key;

  static void inicializarCofre(String chaveDaNuvem) {
    _key = encrypt.Key.fromUtf8(chaveDaNuvem.padRight(32, '!').substring(0, 32));
    _encrypter = encrypt.Encrypter(encrypt.AES(_key!));
  }

  static String criptografar(String texto) {
    if (texto.isEmpty || _encrypter == null) return '';
    try {
      final iv = encrypt.IV.fromSecureRandom(16); 
      return "${iv.base64}:${_encrypter!.encrypt(texto, iv: iv).base64}";  
    } catch (e) { return ''; }
  }

  static String descriptografar(String textoCriptografado) {
    if (textoCriptografado.isEmpty || _encrypter == null) return '';
    try {
      if (textoCriptografado.contains(':')) {
        final parts = textoCriptografado.split(':');
        return _encrypter!.decrypt64(parts[1], iv: encrypt.IV.fromBase64(parts[0]));
      }
      return _encrypter!.decrypt64(textoCriptografado, iv: encrypt.IV.fromLength(16));
    } catch (e) { return ''; }
  }
}

class TratamentoDeErros {
  static String traduzir(dynamic e) {
    if (e == null) return "Ocorreu um erro desconhecido.";
    String erro = e.toString();
    if (erro.contains('SocketException') || erro.contains('network_error')) return "Sem conexão com a internet. Verifique sua rede e tente novamente.";
    if (erro.contains('TimeoutException') || erro.contains('deadline-exceeded')) return "O tempo de conexão esgotou. A internet pode estar lenta.";
    if (erro.contains('user-not-found') || erro.contains('invalid-credential') || erro.contains('wrong-password')) return "E-mail ou senha incorretos. Verifique os dados e tente novamente.";
    if (erro.contains('email-already-in-use')) return "Este e-mail já está cadastrado no sistema.";
    if (erro.contains('invalid-email')) return "O formato do e-mail digitado é inválido.";
    if (erro.contains('weak-password')) return "A senha digitada é muito fraca. Use no mínimo 6 caracteres.";
    if (erro.contains('too-many-requests')) return "Muitas tentativas falhas. Aguarde alguns minutos e tente novamente.";
    if (erro.contains('user-disabled')) return "Esta conta foi suspensa ou desativada pela administração.";
    if (erro.contains('permission-denied')) return "Acesso negado. Você não tem permissão para realizar esta ação.";
    if (erro.contains('not-found')) return "O registro solicitado não foi encontrado ou já foi excluído.";
    if (erro.contains('unavailable')) return "Serviço temporariamente indisponível. Verifique sua conexão.";
    if (erro.contains('internal')) return "Ocorreu um erro interno no servidor. Tente novamente mais tarde.";
    if (erro.startsWith('[') && erro.contains(']')) return erro.substring(erro.indexOf(']') + 1).trim();
    return erro.replaceAll('Exception: ', '').trim();
  }
}

Future<void> registrarAuditoria(String sindicoVinculado, String acao, String modulo, String detalhes) async {
  try {
    await FirebaseFirestore.instance.collection('auditoria').add({'sindico_vinculado': sindicoVinculado, 'operador': operadorLogado, 'acao': acao, 'modulo': modulo, 'detalhes': detalhes, 'data_hora': FieldValue.serverTimestamp(), 'plataforma': kIsWeb ? 'Web' : defaultTargetPlatform.name});
  } catch (e) { debugPrint("Erro ao registrar auditoria: $e"); }
}

class HelperOCR {
  static Future<Map<String, dynamic>> extrairDadosDocumento(Uint8List imageBytes) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = user != null ? await user.getIdToken() : '';
      final response = await http.post(
        Uri.parse('https://processardocumentoocr-hhygy7dtpa-uc.a.run.app'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'data': {'image': base64Encode(imageBytes)}}),
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body)['result'] ?? jsonDecode(response.body)['data'];
        if (responseData != null && responseData['sucesso'] == true) return {'sucesso': true, 'nome': responseData['nome'] ?? '', 'documento': responseData['documento'] ?? ''};
      }
      return {'sucesso': false, 'erro': 'Não foi possível identificar os dados na imagem.'};
    } catch (e) {
      debugPrint("Erro de OCR: $e");
      return {'sucesso': false, 'erro': 'Erro ao conectar com a IA do servidor.'};
    }
  }
}

class HelperOffline {
  static const _cofreSeguro = FlutterSecureStorage();

  static Future<void> salvarChaveCofre(String chave) async {
    await _cofreSeguro.write(key: 'off_chave_mestra', value: chave);
  }

  static Future<void> carregarChaveCofre() async {
    String? chave = await _cofreSeguro.read(key: 'off_chave_mestra');
    if(chave != null && chave.isNotEmpty) CryptoHelper.inicializarCofre(chave);
  }

  static Future<void> salvarNoCofre(String email, String senha, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('off_email', email.toLowerCase());
      await _cofreSeguro.write(key: 'off_senha', value: senha);
      Map<String, dynamic> dadosSeguros = {
        'nome': userData['nome'] ?? 'Morador',
        'email': userData['email'] ?? email,
        'sindico_vinculado': userData['sindico_vinculado'] ?? '',
        'bloco': userData['bloco'] ?? '',
        'ap': userData['ap'] ?? '',
        'perfil': 'morador'
      };
      await prefs.setString('off_user_data', jsonEncode(dadosSeguros));
      debugPrint("💾 [COFRE] Dados salvos com sucesso!");
    } catch (e) {
      debugPrint("❌ [COFRE] Erro ao salvar dados: $e");
    }
  }

  static Future<void> salvarPortoesNoCofre(List<Map<String, dynamic>> portoes) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> portoesSeguros = portoes.map((p) {
      return {
        'id_portao': p['id_portao'],
        'nome': p['nome'],
        'id_box': p['id_box'],
        'codigo': p['codigo'],
        'tempo_abertura': p['tempo_abertura'],
      };
    }).toList();
    await prefs.setString('off_portoes', jsonEncode(portoesSeguros));
  }

  static Future<void> registrarUltimoAcessoOffline() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('off_ultimo_login', DateTime.now().toIso8601String());
  }

  static Future<void> limparCofre() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('off_user_data');
      await prefs.remove('off_email');
      await _cofreSeguro.delete(key: 'off_senha');
      await RadarBluetooth.desligarRadar();
    } catch (_) {}
  }
}

class HelperEmail {
  static Future<Map<String, dynamic>> enviarCodigo({required String emailDestino, required String nome, required String perfil, String? idCondominio}) async {
    try {
      final response = await http.post(
        Uri.parse('https://us-central1-logichome-a9808.cloudfunctions.net/enviarCodigoAutenticacao'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'data': {'email': emailDestino, 'nome': nome, 'perfil': perfil, if (idCondominio != null) 'id_condominio': idCondominio}}),
      );
      if (response.statusCode == 200) {
        final bodyDecoded = jsonDecode(response.body);
        return bodyDecoded['result'] ?? bodyDecoded['data'] ?? {};
      }
      return {'erro': 'Erro no servidor (${response.statusCode})'};
    } catch (e) { return {'erro': 'Erro de conexão: $e'}; }
  }
}

class TelaScanner extends StatefulWidget {
  const TelaScanner({super.key});
  @override
  State<TelaScanner> createState() => _TelaScannerState();
}

class _TelaScannerState extends State<TelaScanner> {
  bool _codigoEncontrado = false; 

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear Código')),
    body: MobileScanner(
      onDetect: (capture) {
        if (_codigoEncontrado) return; 
        if (capture.barcodes.isNotEmpty && capture.barcodes.first.rawValue != null) {
          _codigoEncontrado = true; 
          Navigator.pop(context, capture.barcodes.first.rawValue);
        }
      },
    ),
  );
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) => newValue.copyWith(text: newValue.text.toUpperCase());
}

class DocumentoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
    if (RegExp(r'^[0-9]{11}$').hasMatch(text)) text = '${text.substring(0,3)}.${text.substring(3,6)}.${text.substring(6,9)}-${text.substring(9,11)}';
    return newValue.copyWith(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class PlacaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase();
    if (text.length > 7) text = text.substring(0, 7);
    if (text.length > 3) text = '${text.substring(0,3)}-${text.substring(3)}';
    return newValue.copyWith(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class DataFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (oldValue.text.length > newValue.text.length) return newValue;
    String text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 8) text = text.substring(0, 8);
    String formatado = text.isNotEmpty ? text.substring(0, text.length < 2 ? text.length : 2) : '';
    if (text.length >= 3) formatado += '/${text.substring(2, text.length < 4 ? text.length : 4)}';
    if (text.length >= 5) formatado += '/${text.substring(4, text.length)}';
    return newValue.copyWith(text: formatado, selection: TextSelection.collapsed(offset: formatado.length));
  }
}

class LogoLogicHome extends StatefulWidget {
  final double size;
  const LogoLogicHome({super.key, this.size = 100});
  @override
  State<LogoLogicHome> createState() => _LogoLogicHomeState();
}

class _LogoLogicHomeState extends State<LogoLogicHome> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  @override
  void initState() { super.initState(); _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true); }
  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colorAccent = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF00E5FF) : colorScheme.secondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(animation: _animController, builder: (context, child) => CustomPaint(size: Size(widget.size, widget.size), painter: _LogoPainter(pulseValue: _animController.value, primaryColor: colorScheme.primary, accentColor: colorAccent))),
        const SizedBox(height: 15),
        Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text("LOGIC", style: TextStyle(fontSize: widget.size * 0.35, fontWeight: FontWeight.w900, color: colorScheme.onSurface, letterSpacing: 2)),
          Text("HOME", style: TextStyle(fontSize: widget.size * 0.35, fontWeight: FontWeight.w300, color: colorAccent, letterSpacing: 2)),
        ])
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double pulseValue;
  final Color primaryColor;
  final Color accentColor;
  _LogoPainter({required this.pulseValue, required this.primaryColor, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    double w = size.width / 100, h = size.height / 100;
    canvas.drawPath(Path()..moveTo(50 * w, 5 * h)..lineTo(90 * w, 20 * h)..lineTo(90 * w, 50 * h)..cubicTo(90 * w, 75 * h, 50 * w, 95 * h, 50 * w, 95 * h)..cubicTo(50 * w, 95 * h, 10 * w, 75 * h, 10 * w, 50 * h)..lineTo(10 * w, 20 * h)..close(), Paint()..shader = LinearGradient(colors: [primaryColor.withValues(alpha: 0.5), primaryColor], begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(Rect.fromLTWH(0, 0, size.width, size.height))..style = PaintingStyle.stroke..strokeWidth = 6 * w..strokeJoin = StrokeJoin.round);
    Paint housePaint = Paint()..color = accentColor..style = PaintingStyle.stroke..strokeWidth = 4 * w..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    canvas.drawPath(Path()..moveTo(28 * w, 58 * h)..lineTo(50 * w, 38 * h)..lineTo(72 * w, 58 * h)..lineTo(72 * w, 75 * h)..lineTo(28 * w, 75 * h)..close(), housePaint);
    canvas.drawLine(Offset(50 * w, 38 * h), Offset(50 * w, 62 * h), housePaint);
    if (pulseValue > 0.1) canvas.drawCircle(Offset(50 * w, 62 * h), 6 * w, Paint()..color = accentColor.withValues(alpha: pulseValue * 0.5)..maskFilter = MaskFilter.blur(BlurStyle.normal, (pulseValue * 10 * w).clamp(0.01, 100.0)));
    canvas.drawCircle(Offset(50 * w, 62 * h), (4 + (pulseValue * 2)) * w, Paint()..color = accentColor..style = PaintingStyle.fill);
  }
  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => oldDelegate.pulseValue != pulseValue || oldDelegate.primaryColor != primaryColor || oldDelegate.accentColor != accentColor;
}

void mostrarBrilhoNeon(BuildContext context) {
  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (context) => IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: 0.0), duration: const Duration(milliseconds: 2500), curve: Curves.easeInOut,
        builder: (context, opacity, child) => Opacity(
          opacity: opacity,
          child: Stack(
            children: [
              Positioned(top: 0, left: 0, right: 0, height: 15.0, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCC69F0AE), Colors.transparent])))),
              Positioned(bottom: 0, left: 0, right: 0, height: 15.0, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xCC69F0AE), Colors.transparent])))),
              Positioned(top: 0, bottom: 0, left: 0, width: 15.0, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xCC69F0AE), Colors.transparent])))),
              Positioned(top: 0, bottom: 0, right: 0, width: 15.0, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Color(0xCC69F0AE), Colors.transparent])))),
            ],
          ),
        ),
      ),
    ),
  );
  Overlay.of(context).insert(entry);
  Future.delayed(const Duration(milliseconds: 2500), () => entry?.remove());
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
    await windowManager.ensureInitialized();
    windowManager.waitUntilReadyToShow(const WindowOptions(minimumSize: Size(900, 700), title: 'Logic Home SaaS'), () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    await flutterLocalNotificationsPlugin?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(const AndroidNotificationChannel('logic_home_channel', 'Avisos e Entregas', description: 'Notificações de entregas e comunicados', importance: Importance.max, playSound: true, enableVibration: true));
    await flutterLocalNotificationsPlugin?.initialize(
      InitializationSettings(android: const AndroidInitializationSettings('@mipmap/launcher_icon'), iOS: const DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false)),
      onDidReceiveNotificationResponse: (response) async {
        if (response.payload == 'panico') globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const TelaPanicoAlarme()));
        else if (response.payload == 'abrir_portao_aproximacao') {
          final userEmail = FirebaseAuth.instance.currentUser?.email;
          if (userEmail != null) {
            final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(userEmail).get();
            if (userDoc.exists) globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => TelaAberturaPorAproximacao(userData: userDoc.data()!)));
          }
        } else {
          _redirecionarExpresso('acao_avisos', globalNavigatorKey.currentContext!);
        }
      },
    );
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (message.data['eh_panico'] != "true" && globalNavigatorKey.currentContext != null) _redirecionarExpresso('acao_avisos', globalNavigatorKey.currentContext!);
    });
  }
  MediaKit.ensureInitialized();
  try {
    FirebaseFirestore.instance.settings = (defaultTargetPlatform == TargetPlatform.windows) ? const Settings(persistenceEnabled: false) : const Settings(persistenceEnabled: true, cacheSizeBytes: 104857600);
  } catch (e) { debugPrint("Configuração de persistência ignorada: $e"); }
  
  themeNotifier.carregarTemaSalvo((await SharedPreferences.getInstance()).getString('tema_escolhido') ?? 'neon');

  String rotaInicial = '/';
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null && initialMessage.data['eh_panico'] != "true") rotaInicial = '/avisos';
    final launchDetails = await flutterLocalNotificationsPlugin?.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      if (launchDetails?.notificationResponse?.payload == 'panico') rotaInicial = '/panico_urgente';
      else if (launchDetails?.notificationResponse?.payload == 'abrir_portao_aproximacao') rotaInicial = '/aproximacao';
    }
    FlutterCallkitIncoming.onEvent.listen((event) {
      if (event?.event == Event.actionCallAccept) globalNavigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const TelaPanicoAlarme()));
      else if (event?.event == Event.actionCallDecline) { FlutterCallkitIncoming.endAllCalls(); debugPrint("Alarme de pânico rejeitado/silenciado pelo Síndico."); }
    });
  }
  runApp(LogicHomeApp(rotaStart: rotaInicial));
}

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark; 
  Color _seedColor = const Color(0xFF00E5FF); 
  bool _isNeonTheme = true; 

  ThemeMode get mode => _mode;
  Color get seedColor => _seedColor;
  bool get isNeonTheme => _isNeonTheme;

  void carregarTemaSalvo(String temaKey) {
    if (temaKey == 'neon') _aplicarTema(ThemeMode.dark, const Color(0xFF00E5FF), true);
    else if (temaKey == 'light_blue') _aplicarTema(ThemeMode.light, const Color(0xFF0D47A1), false);
    else if (temaKey == 'dark') _aplicarTema(ThemeMode.dark, const Color(0xFF424242), false);
    else if (temaKey == 'dark_blue') _aplicarTema(ThemeMode.dark, const Color(0xFF1A237E), false);
    else if (temaKey == 'brown') _aplicarTema(ThemeMode.light, const Color(0xFF8B4513), false);
  }

  void _aplicarTema(ThemeMode m, Color c, bool neon) { _mode = m; _seedColor = c; _isNeonTheme = neon; notifyListeners(); }
  Future<void> setTheme(String temaKey) async { carregarTemaSalvo(temaKey); await (await SharedPreferences.getInstance()).setString('tema_escolhido', temaKey); }
}
final themeNotifier = ThemeNotifier();

class LogicHomeApp extends StatefulWidget {
  final String rotaStart;
  const LogicHomeApp({super.key, this.rotaStart = '/'});
  @override
  State<LogicHomeApp> createState() => _LogicHomeAppState();
}

class _LogicHomeAppState extends State<LogicHomeApp> {
  @override
  void initState() { super.initState(); themeNotifier.addListener(() => setState(() {})); }
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: globalNavigatorKey, debugShowCheckedModeBanner: false, title: 'Logic Home SaaS',
    builder: (context, child) => themeNotifier.isNeonTheme ? Scaffold(backgroundColor: Colors.transparent, body: Stack(children: [const Positioned.fill(child: GridBackground()), if (child != null) child])) : child!,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: themeNotifier.seedColor, brightness: Brightness.light), useMaterial3: true),
    darkTheme: ThemeData.dark().copyWith(colorScheme: ColorScheme.fromSeed(seedColor: themeNotifier.seedColor, brightness: Brightness.dark), scaffoldBackgroundColor: themeNotifier.isNeonTheme ? Colors.transparent : null),
    themeMode: themeNotifier.mode,
    onGenerateInitialRoutes: (initialRoute) {
      if (widget.rotaStart == '/panico_urgente') return [MaterialPageRoute(builder: (_) => const TelaPanicoAlarme())];
      if (widget.rotaStart == '/aproximacao') return [MaterialPageRoute(builder: (_) => const TelaLogin(redirecionarParaAproximacao: true))];
      if (widget.rotaStart == '/avisos') return [MaterialPageRoute(builder: (_) => const TelaLogin(redirecionarParaAvisos: true))];
      if (widget.rotaStart == '/encomendas') return [MaterialPageRoute(builder: (_) => const TelaLogin(redirecionarParaEncomendas: true))];
      if (widget.rotaStart == '/faturas') return [MaterialPageRoute(builder: (_) => const TelaLogin(redirecionarParaFaturas: true))];
      if (widget.rotaStart == '/reservas') return [MaterialPageRoute(builder: (_) => const TelaLogin(redirecionarParaReservas: true))];
      if (initialRoute.startsWith('/vip/')) return [MaterialPageRoute(builder: (_) => TelaFormularioVIP(tokenConvite: initialRoute.split('/')[2]))];
      return [MaterialPageRoute(builder: (_) => const TelaLogin())];
    },
    onGenerateRoute: (settings) {
      return MaterialPageRoute(builder: (_) {
        if (settings.name == '/avisos') return const TelaLogin(redirecionarParaAvisos: true);
        if (settings.name == '/encomendas') return const TelaLogin(redirecionarParaEncomendas: true);
        if (settings.name == '/faturas') return const TelaLogin(redirecionarParaFaturas: true);
        if (settings.name == '/reservas') return const TelaLogin(redirecionarParaReservas: true);
        if (settings.name?.startsWith('/vip/') ?? false) return TelaFormularioVIP(tokenConvite: settings.name!.split('/')[2]);
        return const TelaLogin();
      });
    },
  );
}

class BotaoTrocarTema extends StatelessWidget {
  const BotaoTrocarTema({super.key});
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    icon: const Icon(Icons.palette_outlined),
    onSelected: themeNotifier.setTheme,
    itemBuilder: (_) => const [PopupMenuItem(value: 'neon', child: Text("Tema Neon (SaaS Padrão)")), PopupMenuItem(value: 'light_blue', child: Text("Tema Azul (Claro)")), PopupMenuItem(value: 'dark', child: Text("Tema Escuro Clássico")), PopupMenuItem(value: 'dark_blue', child: Text("Tema Azul (Escuro)")), PopupMenuItem(value: 'brown', child: Text("Tema Marrom (Claro)"))],
  );
}

class TelaPanicoAlarme extends StatefulWidget {
  const TelaPanicoAlarme({super.key});
  @override
  State<TelaPanicoAlarme> createState() => _TelaPanicoAlarmeState();
}

class _TelaPanicoAlarmeState extends State<TelaPanicoAlarme> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Player? _playerSirene;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _playerSirene = Player()..open(Media('asset:///assets/sirene.mp3'))..setPlaylistMode(PlaylistMode.loop)..play();
  }

  void _desligarAlarme() { _playerSirene?.stop(); flutterLocalNotificationsPlugin?.cancelAll(); Navigator.pop(context); }

  @override
  void dispose() { _playerSirene?.dispose(); _pulseController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: RadialGradient(center: Alignment.center, radius: 1.5, colors: [Colors.red.shade900, Colors.black])),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 100), const SizedBox(height: 20),
            const Text("SISTEMA DE SEGURANÇA", style: TextStyle(color: Colors.white70, fontSize: 18, letterSpacing: 2)), const SizedBox(height: 10),
            FadeTransition(opacity: _pulseController, child: const Text("PÂNICO ACIONADO", style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold))), const SizedBox(height: 10),
            const Text("Emergência na Portaria!", style: TextStyle(color: Colors.redAccent, fontSize: 20)),
          ]),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: SliderDesligar(onSlid: _desligarAlarme))
        ],
      )
    )
  );
}

class SliderDesligar extends StatefulWidget {
  final VoidCallback onSlid;
  const SliderDesligar({super.key, required this.onSlid});
  @override
  State<SliderDesligar> createState() => _SliderDesligarState();
}

class _SliderDesligarState extends State<SliderDesligar> {
  double _dragPosition = 0.0;
  final double _maxDrag = 220.0;

  @override
  Widget build(BuildContext context) => Container(
    height: 75, width: _maxDrag + 75, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(40)),
    child: Stack(children: [
      const Center(child: Text("DESLIZE PARA DESLIGAR  >>>", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 14))),
      Positioned(
        left: _dragPosition,
        child: GestureDetector(
          onHorizontalDragUpdate: (details) => setState(() => _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, _maxDrag)),
          onHorizontalDragEnd: (_) { if (_dragPosition > _maxDrag * 0.8) widget.onSlid(); else setState(() => _dragPosition = 0.0); },
          child: Container(height: 75, width: 75, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.call_end, color: Colors.white, size: 35)),
        ),
      )
    ]),
  );
}

// [FIM DO BLOCO - DIGITE "CONTINUE" PARA GERAR A PRÓXIMA PARTE]
// ============================================================================
// PARTE 3 - ESTRUTURA BASE (PAINÉIS DE NAVEGAÇÃO)
// ============================================================================

final GlobalKey keyBotaoPanico = GlobalKey(), keyMenuEncomendas = GlobalKey(), keyMenuVisitantes = GlobalKey(), keyMenuBiometria = GlobalKey(), keyMenuCameras = GlobalKey(), keyMenuPortoes = GlobalKey(), keyTutPorCentro = GlobalKey(), keyMenuReservas = GlobalKey(), keyMenuGestao = GlobalKey(), keyBotaoAjuda = GlobalKey(), keyMenuMuralSininho = GlobalKey(), keyMenuAnotacoes = GlobalKey(), keyMenuRonda = GlobalKey(), keyMenuSobre = GlobalKey(), keyTopTema = GlobalKey(), keyTopSair = GlobalKey(), keyTutEstBusca = GlobalKey(), keyTutVisBusca = GlobalKey(), keyTutVisFiltros = GlobalKey(), keyTutResFiltros = GlobalKey(), keyTutEncReceber = GlobalKey(), keyTutEncRetirar = GlobalKey(), keyTutEncAbas = GlobalKey(), keyTutVisOcr = GlobalKey(), keyTutVisManual = GlobalKey(), keyTutVisVip = GlobalKey(), keyTutBioFoto = GlobalKey(), keyTutBioSync = GlobalKey(), keyTutResNova = GlobalKey(), keyTutResAba1 = GlobalKey(), keyTutResAba2 = GlobalKey(), keyTutResAba3 = GlobalKey(), keyTutGesNovoPorteiro = GlobalKey(), keyTutGesAbaMoradores = GlobalKey(), keyTutGesAbaPermissoes = GlobalKey(), keyTutNotNovo = GlobalKey(), keyTutAnotacaoNova = GlobalKey(), keyTutRondaBotao = GlobalKey(), keyTutGestaoRondaNova = GlobalKey(), keyTutGestaoRondaFiltro = GlobalKey();

class PainelEstrutural extends StatefulWidget {
  final String perfil, emailSindico;
  final Map<String, dynamic> funcionalidadesPermitidas, menusPersonalizados;
  final bool podeTrocarCondominio;

  const PainelEstrutural({super.key, required this.perfil, required this.emailSindico, required this.funcionalidadesPermitidas, this.menusPersonalizados = const {}, this.podeTrocarCondominio = false});

  @override
  State<PainelEstrutural> createState() => _PainelEstruturalState();
}

class _PainelEstruturalState extends State<PainelEstrutural> with WidgetsBindingObserver {
  int _index = 0;
  late Stream<DocumentSnapshot> _infoCondominioStream;
  bool _processandoTransferencia = false, _internetEstavaMorta = false, _estePcEServidor = false, _panicoEmEspera = false;
  Timer? _heartbeatTimer, _timerChacoalho;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  DateTime _ultimoMovimentoG = DateTime.now();
  int _contagemChacoalhoes = 0;
  List<Map<String, dynamic>> _menuAtual = []; 

  void _irParaAba(String labelAlvo, VoidCallback aoChegar) {
    final idx = _menuAtual.indexWhere((item) => item['label'] == labelAlvo);
    if (idx != -1) { setState(() => _index = idx); Future.delayed(const Duration(milliseconds: 500), aoChegar); }
    else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Você não tem permissão para acessar este módulo.")));
  }

  void _abrirCentralDeTreinamento() {
    final isSindico = widget.perfil == 'sindico';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [Icon(Icons.school, color: Colors.blue), SizedBox(width: 10), Text("Academia Logic Home")]),
        contentPadding: const EdgeInsets.all(20), scrollable: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FECHAR"))],
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Selecione o módulo para iniciar o guia interativo:", style: TextStyle(fontSize: 14, color: Colors.grey)), const SizedBox(height: 15),
          _itemAula(ctx, Icons.dashboard, Colors.blue, "Módulo 1: Conhecendo o Menu", () => _iniciarTutorialMenuPrincipal()), const Divider(),
          _itemAula(ctx, Icons.inventory_2, Colors.orange, "Módulo 2: Encomendas", () => _irParaAba('Encomendas', _iniciarTutorialEncomendas)), const Divider(),
          _itemAula(ctx, Icons.people, Colors.purple, "Módulo 3: Visitantes", () => _irParaAba('Visitantes', _iniciarTutorialVisitantes)), const Divider(),
          _itemAula(ctx, Icons.face, Colors.indigo, "Módulo 4: Biometria Facial", () => _irParaAba('Biometria Facial', _iniciarTutorialBiometria)), const Divider(),
          _itemAula(ctx, Icons.door_sliding, Colors.brown, "Módulo 5: Câmeras e Portões", () => _irParaAba('Portões', _iniciarTutorialPortoes)), const Divider(),
          _itemAula(ctx, Icons.deck, Colors.green, "Módulo 6: Áreas Comuns", () => _irParaAba('Reservas', _iniciarTutorialReservas)),
          if (isSindico) ...[const Divider(), _itemAula(ctx, Icons.manage_accounts, Colors.redAccent, "Módulo 7: Gestão do Síndico", () => _irParaAba('Gestão', _iniciarTutorialGestao))],
          const Divider(),
          _itemAula(ctx, Icons.campaign, Colors.teal, "Módulo 8: Disparar Avisos", () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => TelaNotificacoes(perfil: widget.perfil, emailUsuario: widget.emailSindico, emailSindico: widget.emailSindico))).then((_) => Future.delayed(const Duration(milliseconds: 500), _iniciarTutorialNotificacoes)); }, mantemAberto: true),
          if (widget.perfil == 'porteiro') ...[const Divider(), _itemAula(ctx, Icons.push_pin, Colors.amber, "Módulo 9: Anotações da Portaria", () => _irParaAba('Anotações', _iniciarTutorialAnotacoes)), const Divider(), _itemAula(ctx, Icons.shield_moon, Colors.deepPurple, "Módulo 10: Ronda Virtual", () => _irParaAba('Ronda Virtual', _iniciarTutorialRonda))],
          if (isSindico) ...[const Divider(), _itemAula(ctx, Icons.shield_moon, Colors.deepPurple, "Módulo 9: Gestão de Rondas", () => _irParaAba('Rondas (Gestão)', _iniciarTutorialGestaoRondas))],
          const Divider(), _itemAula(ctx, Icons.info_outline, Colors.grey, "Módulo Extra: Sobre o Sistema", () => _irParaAba('Sobre o Sistema', _iniciarTutorialSobre)),
        ]),
      )
    );
  }

  Widget _itemAula(BuildContext ctx, IconData icone, Color cor, String titulo, VoidCallback acao, {bool mantemAberto = false}) => ListTile(leading: Icon(icone, color: cor), title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: const Icon(Icons.play_circle_fill, color: Colors.green), onTap: () { if (!mantemAberto) Navigator.pop(ctx); acao(); });

  void _iniciarTutorialMenuPrincipal() {
    if (MediaQuery.of(context).size.width < 800) Scaffold.of(context).openDrawer();
    TutorialCoachMark(targets: [
      TargetFocus(identify: "Panico", keyTarget: keyBotaoPanico, shape: ShapeLightFocus.RRect, paddingFocus: 2, alignSkip: Alignment.topRight, contents: [TargetContent(align: ContentAlign.right, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.warning, titulo: "Botão de Emergência", texto: "Se a portaria for rendida, CLIQUE E SEGURE o logotipo ou aperte F12.\nIsso envia um alerta silencioso e imediato para o Síndico."))]),
      TargetFocus(identify: "MnuEnc", keyTarget: keyMenuEncomendas, shape: ShapeLightFocus.RRect, paddingFocus: 2, contents: [TargetContent(align: ContentAlign.right, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.inventory_2, titulo: "Pacotes e Correios", texto: "Aqui você gerencia a entrada e a entrega de caixas aos moradores."))]),
      TargetFocus(identify: "MnuVis", keyTarget: keyMenuVisitantes, shape: ShapeLightFocus.RRect, paddingFocus: 2, contents: [TargetContent(align: ContentAlign.right, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.people, titulo: "Controle de Acesso", texto: "Aqui você registra quem entra e sai, lendo documentos com a câmera."))]),
      TargetFocus(identify: "MnuBio", keyTarget: keyMenuBiometria, shape: ShapeLightFocus.RRect, paddingFocus: 2, contents: [TargetContent(align: ContentAlign.right, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.face, titulo: "Cadastro Facial", texto: "Tire fotos dos moradores e envie direto para as catracas da Intelbras ou Control iD."))]),
      TargetFocus(identify: "MnuCam", keyTarget: keyMenuCameras, shape: ShapeLightFocus.RRect, paddingFocus: 2, contents: [TargetContent(align: ContentAlign.right, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.videocam, titulo: "Mosaico de Vídeo", texto: "Assista a todas as câmeras do condomínio ao vivo e controle o PTZ."))]),
      TargetFocus(identify: "MnuPor", keyTarget: keyMenuPortoes, shape: ShapeLightFocus.RRect, paddingFocus: 2, contents: [TargetContent(align: ContentAlign.right, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.door_sliding, titulo: "Abertura de Portões", texto: "Veja quem está na frente do portão e clique para abrir pela rede local."))]),
      TargetFocus(identify: "MnuSino", keyTarget: keyMenuMuralSininho, shape: ShapeLightFocus.Circle, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.notifications, titulo: "O Sininho", texto: "Acesse o mural para ler comunicados ou disparar Push Notifications."))]),
      TargetFocus(identify: "MnuTema", keyTarget: keyTopTema, shape: ShapeLightFocus.Circle, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.palette, titulo: "Cores do Sistema", texto: "Cansado da cor atual? Clique aqui para mudar o visual (Tema Claro, Escuro, Neon)."))]),
      TargetFocus(identify: "MnuSair", keyTarget: keyTopSair, shape: ShapeLightFocus.Circle, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.logout, titulo: "Sair do Turno", texto: "Fim do expediente? Não esqueça de clicar aqui para deslogar do sistema por segurança."))]),
    ], colorShadow: Colors.black, hideSkip: true, paddingFocus: 5, opacityShadow: 0.9).show(context: context);
  }

  void _iniciarTutorialEncomendas() => TutorialCoachMark(targets: [
    TargetFocus(identify: "Receber", keyTarget: keyTutEncReceber, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.add_box, titulo: "1. Receber Encomendas", texto: "Abra um Lote e bipe os pacotes com o leitor USB. O sistema alertará o morador no App."))]),
    TargetFocus(identify: "Retirar", keyTarget: keyTutEncRetirar, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.outbox, titulo: "2. Entregar ao Morador", texto: "Digite o PIN de 4 dígitos que o morador mostrar no celular para entregar o pacote correto."))]),
    TargetFocus(identify: "Abas", keyTarget: keyTutEncAbas, shape: ShapeLightFocus.RRect, paddingFocus: 2, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.folder, titulo: "3. Prateleira e Histórico", texto: "Alterne aqui entre o que está guardado e o que já foi entregue."))]),
    TargetFocus(identify: "BuscaEst", keyTarget: keyTutEstBusca, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.search, titulo: "4. Busca Rápida", texto: "Precisa achar uma caixa rápido? Digite o código de rastreio, o nome do morador ou o apartamento aqui."))]),
  ], colorShadow: Colors.black, hideSkip: true, opacityShadow: 0.9).show(context: context);

  void _iniciarTutorialVisitantes() => TutorialCoachMark(targets: [
    TargetFocus(identify: "OCR", keyTarget: keyTutVisOcr, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.document_scanner, titulo: "1. Leitura Inteligente", texto: "Tire foto do RG/CNH. A Inteligência Artificial vai preencher o Nome e Documento sozinha!"))]),
    TargetFocus(identify: "Manual", keyTarget: keyTutVisManual, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.edit_document, titulo: "2. Cadastro Manual", texto: "Se o visitante não tiver documento com foto, digite os dados manualmente aqui."))]),
    TargetFocus(identify: "VIP", keyTarget: keyTutVisVip, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.star, titulo: "3. Visitante VIP", texto: "O morador gerou um PIN no app? Digite-o aqui para liberar a entrada sem preencher nada."))]),
    TargetFocus(identify: "BuscaVis", keyTarget: keyTutVisBusca, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.search, titulo: "4. Procurar Visitante", texto: "Digite o nome ou placa do veículo para achar um visitante específico na lista."))]),
    TargetFocus(identify: "FiltroVis", keyTarget: keyTutVisFiltros, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.filter_list, titulo: "5. Filtro de Presença", texto: "Mude para 'Presentes' para ver exatamente quem AINDA está dentro do condomínio neste momento."))]),
  ], colorShadow: Colors.black, hideSkip: true, opacityShadow: 0.9).show(context: context);

  void _iniciarTutorialBiometria() => TutorialCoachMark(targets: [
    TargetFocus(identify: "BioFoto", keyTarget: keyTutBioFoto, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.camera_alt, titulo: "1. Tirar Foto", texto: "Busque o morador na lista e clique aqui para fotografar o rosto dele usando a webcam."))]),
    TargetFocus(identify: "BioSync", keyTarget: keyTutBioSync, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.sync, titulo: "2. Injetar na Catraca", texto: "Após salvar a foto, clique aqui. O sistema enviará o rosto para a catraca Intelbras/Control iD localmente."))]),
  ], colorShadow: Colors.black, hideSkip: true, opacityShadow: 0.9).show(context: context);

  void _iniciarTutorialPortoes() => TutorialCoachMark(targets: [
    TargetFocus(identify: "CentroPortoes", keyTarget: keyTutPorCentro, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.top, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.door_sliding, titulo: "Painel de Abertura", texto: "Nesta área central você verá as câmeras ao vivo e os controles de acesso.\n\nPara liberar a entrada, basta clicar no botão verde 'ABRIR PORTÃO' e o pulso será enviado instantaneamente."))]),
  ], colorShadow: Colors.black, hideSkip: true, opacityShadow: 0.9).show(context: context);

  void _iniciarTutorialReservas() => TutorialCoachMark(targets: [
    if (widget.perfil == 'sindico') TargetFocus(identify: "NovaArea", keyTarget: keyTutResNova, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.top, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.add_location, titulo: "1. Criar Área Comum", texto: "Cadastre Salões e Quiosques, defina os turnos e os dias mínimos de antecedência."))]),
    if (widget.perfil == 'sindico') TargetFocus(identify: "Aba1", keyTarget: keyTutResAba1, shape: ShapeLightFocus.RRect, paddingFocus: 2, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.tab, titulo: "2. Áreas Criadas", texto: "Esta aba mostra as regras dos espaços que você criou."))]),
    TargetFocus(identify: "Aba2", keyTarget: keyTutResAba2, shape: ShapeLightFocus.RRect, paddingFocus: 2, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.tab, titulo: "3. Visão da Portaria", texto: "Aqui fica a lista de quem alugou o espaço HOJE para o porteiro liberar convidados."))]),
    if (widget.perfil == 'sindico') TargetFocus(identify: "Aba3", keyTarget: keyTutResAba3, shape: ShapeLightFocus.RRect, paddingFocus: 2, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.tab, titulo: "4. Filas e Histórico", texto: "Histórico completo de aluguéis passados."))]),
    if (widget.perfil == 'sindico') TargetFocus(identify: "FiltroRes", keyTarget: keyTutResFiltros, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.filter_list, titulo: "5. Fila de Espera", texto: "Mude para 'Fila de Espera'. Se você cancelar uma reserva, o sistema vai notificar o morador que está nessa fila!"))]),
  ], colorShadow: Colors.black, hideSkip: true, opacityShadow: 0.9).show(context: context);

  void _iniciarTutorialGestao() => TutorialCoachMark(targets: [
    TargetFocus(identify: "Porteiro", keyTarget: keyTutGesNovoPorteiro, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.top, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.security, titulo: "1. Novo Porteiro", texto: "Crie senhas para novos porteiros ou apague as de quem foi desligado."))]),
    TargetFocus(identify: "AbaMor", keyTarget: keyTutGesAbaMoradores, shape: ShapeLightFocus.RRect, paddingFocus: 2, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.people, titulo: "2. Aprovar Moradores", texto: "Nesta aba, clique no morador pendente (amarelo) para aprovar e liberar o App dele."))]),
    TargetFocus(identify: "AbaPerm", keyTarget: keyTutGesAbaPermissoes, shape: ShapeLightFocus.RRect, paddingFocus: 2, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.lock, titulo: "3. Permissões de App", texto: "Aqui você bloqueia o salão para inadimplentes e libera câmeras pro morador ver no celular."))]),
  ], colorShadow: Colors.black, hideSkip: true, opacityShadow: 0.9).show(context: context);

  void _iniciarTutorialNotificacoes() => TutorialCoachMark(targets: [
    TargetFocus(identify: "Aviso", keyTarget: keyTutNotNovo, shape: ShapeLightFocus.RRect, paddingFocus: 5, alignSkip: Alignment.bottomRight, contents: [TargetContent(align: ContentAlign.top, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.campaign, titulo: "Mural de Avisos", texto: "Clique aqui para disparar um Push Notification pro celular do condomínio todo ou apenas de um apartamento específico."))]),
  ], colorShadow: Colors.black, hideSkip: true, opacityShadow: 0.9).show(context: context);

  void _iniciarTutorialAnotacoes() => TutorialCoachMark(targets: [
    TargetFocus(identify: "NovaAnotacao", keyTarget: keyTutAnotacaoNova, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.top, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.push_pin, titulo: "1. Criar Recado", texto: "Clique aqui para escrever um recado ou fotografar um papel na portaria. Isso ficará visível para o próximo turno."))]),
  ], colorShadow: Colors.black, hideSkip: true, opacityShadow: 0.9).show(context: context);

  void _iniciarTutorialRonda() => TutorialCoachMark(targets: [
    TargetFocus(identify: "BotaoRonda", keyTarget: keyTutRondaBotao, shape: ShapeLightFocus.Circle, paddingFocus: 10, contents: [TargetContent(align: ContentAlign.top, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.fingerprint, titulo: "1. Registrar Ronda", texto: "Quando o sistema alertar e este botão ficar vermelho, clique nele para confirmar que você está acordado e atento na portaria."))]),
  ], colorShadow: Colors.black, hideSkip: true, opacityShadow: 0.9).show(context: context);

  void _iniciarTutorialSobre() => TutorialCoachMark(targets: [
    TargetFocus(identify: "MenuSobre", keyTarget: keyMenuSobre, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.right, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.info, titulo: "Sobre a Tecnologia", texto: "Aqui você encontra detalhes sobre o funcionamento da plataforma SaaS e as tecnologias utilizadas na operação do condomínio."))]),
  ], colorShadow: Colors.black, hideSkip: true, opacityShadow: 0.9).show(context: context);

  void _iniciarTutorialGestaoRondas() => TutorialCoachMark(targets: [
    TargetFocus(identify: "NovaRonda", keyTarget: keyTutGestaoRondaNova, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.top, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.add_alarm, titulo: "1. Programar Nova Ronda", texto: "Clique aqui para definir os horários em que o porteiro deverá registrar atividade na madrugada."))]),
    TargetFocus(identify: "FiltroRonda", keyTarget: keyTutGestaoRondaFiltro, shape: ShapeLightFocus.RRect, paddingFocus: 5, contents: [TargetContent(align: ContentAlign.bottom, builder: (ctx, c) => CardTutorial(controller: c, icone: Icons.search, titulo: "2. Relatório e Filtros", texto: "Na aba 'Relatório de Execução', você pode filtrar os atrasos e as faltas por data ou pelo nome do porteiro."))]),
  ], colorShadow: Colors.black, hideSkip: true, opacityShadow: 0.9).show(context: context);

  @override
  void initState() {
    super.initState();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      try { 
        await FirebaseAuth.instance.currentUser?.getIdToken(true); 
        if (_internetEstavaMorta) {
           debugPrint("🌐 AUTO-HEAL: A internet voltou! Reiniciando Túnel de Vídeo...");
           _internetEstavaMorta = false;
           if (widget.perfil == 'porteiro' && _estePcEServidor) GerenciadorDeTunel.reiniciarTudo(widget.emailSindico);
        }
      } catch (e) {
        debugPrint("❌ AUTO-HEAL: Sem conexão com a internet detectada.");
        _internetEstavaMorta = true;
      }
    });
    
    HardwareKeyboard.instance.addHandler(_tecladoListener);

    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      _accelerometerSubscription = accelerometerEventStream().listen((event) {
        double gForce = sqrt(pow(event.x / 9.80665, 2) + pow(event.y / 9.80665, 2) + pow(event.z / 9.80665, 2));
        if (gForce > 2.5) {
          final agora = DateTime.now();
          if (agora.difference(_ultimoMovimentoG).inMilliseconds > 500) {
            _ultimoMovimentoG = agora; _contagemChacoalhoes++; _timerChacoalho?.cancel();
            if (_contagemChacoalhoes >= 3) { _contagemChacoalhoes = 0; _dispararPanicoSilencioso(); }
            else _timerChacoalho = Timer(const Duration(seconds: 3), () => _contagemChacoalhoes = 0);
          }
        }
      });
    }

    WidgetsBinding.instance.addObserver(this); 
    _verificarEIniciarServidorLocal();
    _initStreams(); 
    if (FirebaseAuth.instance.currentUser != null) _configurarPushNotifications(FirebaseAuth.instance.currentUser!.email!);
  }

  Future<void> _verificarEIniciarServidorLocal() async {
    if (widget.perfil == 'porteiro') {
      _estePcEServidor = (await SharedPreferences.getInstance()).getBool('is_servidor_local') ?? false;
      if (_estePcEServidor) { debugPrint("🖥️ Este PC é o SERVIDOR! Iniciando Motores (Vídeo/Robô)..."); GerenciadorDeTunel.iniciar(widget.emailSindico); }
      else debugPrint("💻 Este PC é apenas um Terminal. Motores desligados.");
    }
  }

  void _initStreams() {
    if (widget.emailSindico.isNotEmpty) {
      _infoCondominioStream = FirebaseFirestore.instance.collection('usuarios').doc(widget.emailSindico).snapshots();
      if (widget.perfil == 'porteiro') {
        FirebaseFirestore.instance.collection('esperando_delivery').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots().listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              try {
                final hora = DateTime.now().hour;
                final arquivoSom = hora < 12 ? 'asset:///assets/delivery_manha.mp3' : (hora < 18 ? 'asset:///assets/delivery_tarde.mp3' : 'asset:///assets/delivery_noite.mp3');
                final player = Player()..open(Media(arquivoSom));
                Future.delayed(const Duration(seconds: 5), () => player.dispose());
                
                final data = change.doc.data() as Map<String, dynamic>;
                Future.delayed(const Duration(milliseconds: 3200), () async {
                  try {
                    final playerVoz = Player()..open(Media("https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&q=${Uri.encodeComponent("Bloco ${data['bloco']}. Apartamento ${data['ap']}.")}&tl=pt-BR"));
                    Future.delayed(const Duration(seconds: 5), () => playerVoz.dispose());
                  } catch (e) { debugPrint("Erro ao tocar voz natural do Google: $e"); }
                });
              } catch (e) { debugPrint("Erro ao tocar sistema híbrido de voz: $e"); }
            }
          }
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) FirebaseAuth.instance.currentUser?.getIdToken(true); }

  Future<void> _configurarPushNotifications(String emailUsuario) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) return;
    try {
      final messaging = FirebaseMessaging.instance;
      if ((await messaging.requestPermission(alert: true, badge: true, sound: true)).authorizationStatus == AuthorizationStatus.authorized) {
        final token = await messaging.getToken();
        if (token != null) await FirebaseFirestore.instance.collection('usuarios').doc(emailUsuario).update({'fcm_tokens': FieldValue.arrayUnion([token])});
        messaging.onTokenRefresh.listen((nt) => FirebaseFirestore.instance.collection('usuarios').doc(emailUsuario).update({'fcm_tokens': FieldValue.arrayUnion([nt])}));

        if (defaultTargetPlatform == TargetPlatform.android) {
          await flutterLocalNotificationsPlugin?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
            const AndroidNotificationChannel('canal_panico_absoluto_v10', 'Emergências e Pânico', description: 'Alarmes de pânico da portaria', importance: Importance.max, playSound: true, sound: RawResourceAndroidNotificationSound('sirene'), enableVibration: true, audioAttributesUsage: AudioAttributesUsage.alarm)
          );
        }

        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.data['eh_panico'] == "true") {
            if (globalNavigatorKey.currentState != null) globalNavigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const TelaPanicoAlarme()));
            flutterLocalNotificationsPlugin?.show(
              message.hashCode, message.data['title'], message.data['body'],
              const NotificationDetails(android: AndroidNotificationDetails('canal_panico_absoluto_v10', 'Emergências e Pânico', importance: Importance.max, priority: Priority.max, color: Colors.red, sound: RawResourceAndroidNotificationSound('sirene'), playSound: true, enableVibration: true, fullScreenIntent: true, audioAttributesUsage: AudioAttributesUsage.alarm, category: AndroidNotificationCategory.alarm), iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true, sound: 'sirene.mp3', interruptionLevel: InterruptionLevel.critical)),
              payload: 'panico',
            );
          } else {
            final titulo = message.notification?.title ?? message.data['title'] ?? message.data['titulo'];
            final corpo = message.notification?.body ?? message.data['body'] ?? message.data['mensagem'];
            if (titulo != null && corpo != null && defaultTargetPlatform == TargetPlatform.android) {
              flutterLocalNotificationsPlugin?.show(
                message.hashCode, titulo, corpo,
                const NotificationDetails(android: AndroidNotificationDetails('logic_home_channel', 'Avisos e Entregas', importance: Importance.max, priority: Priority.high, color: Color(0xFF00E5FF), playSound: true, enableVibration: true), iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true)),
                payload: message.data['tipo_acao'] ?? 'acao_avisos',
              );
            }
          }
        });
      }
    } catch (e) { debugPrint("Erro ao configurar notificações push: $e"); }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel(); WidgetsBinding.instance.removeObserver(this); GerenciadorDeTunel.desligarTudo();
    HardwareKeyboard.instance.removeHandler(_tecladoListener); _accelerometerSubscription?.cancel(); _timerChacoalho?.cancel();
    super.dispose();
  }
  
  Future<void> _dispararPanicoSilencioso() async {
    if (_panicoEmEspera) return; _panicoEmEspera = true;
    try {
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) && await Vibration.hasVibrator() == true) Vibration.vibrate(duration: 500);
      await registrarAuditoria(widget.emailSindico, "🚨 PÂNICO ACIONADO", "Segurança", "O operador $operadorLogado acionou o botão de pânico silencioso (Hardware).");
      await FirebaseFirestore.instance.collection('notificacoes').add({'sindico_vinculado': widget.emailSindico, 'para': widget.emailSindico, 'nome_destino': 'Síndico', 'titulo': '🚨 ALERTA DE PÂNICO NA PORTARIA!', 'mensagem': 'O operador $operadorLogado acabou de acionar o botão de emergência silencioso. Verifique as câmeras e tente contato IMEDIATO.', 'data': FieldValue.serverTimestamp(), 'remetente': 'SISTEMA DE SEGURANÇA'});
      debugPrint("Pânico disparado com sucesso!");
    } catch (e) { debugPrint("Erro ao disparar pânico: $e"); }
    Future.delayed(const Duration(seconds: 30), () { if (mounted) setState(() => _panicoEmEspera = false); });
  }

  bool _tecladoListener(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f12) { _dispararPanicoSilencioso(); return true; }
    return false;
  }

  bool _temAcesso(String chave) => widget.perfil != 'tecnico' && (widget.menusPersonalizados[chave] ?? widget.funcionalidadesPermitidas.isEmpty || widget.funcionalidadesPermitidas[chave] == true);

  @override
  Widget build(BuildContext context) {
    final isSindico = widget.perfil == 'sindico', isTecnico = widget.perfil == 'tecnico', isMobile = MediaQuery.of(context).size.width < 800;
    final colorScheme = Theme.of(context).colorScheme;

    List<Map<String, dynamic>> itensMenu = [];
    List<Widget> telas = [];

    if (isTecnico) {
      itensMenu = [{'icon': Icons.router, 'label': 'Hardware iDBox'}, {'icon': Icons.door_sliding, 'label': 'Portões'}, {'icon': Icons.videocam, 'label': 'Câmeras'}, {'icon': Icons.face_retouching_natural, 'label': 'Equip. Facial'}, {'icon': Icons.cloud_sync, 'label': 'Túnel 4G (Nuvem)'}, {'icon': Icons.dns, 'label': 'Servidor Câmera/Robô'}];
      telas = [TelaHardwareIDBox(emailSindico: widget.emailSindico), TelaPortoes(emailSindico: widget.emailSindico, perfil: widget.perfil), TelaCameras(emailSindico: widget.emailSindico, perfil: widget.perfil), TelaHardwareFacial(emailSindico: widget.emailSindico), TelaConfiguracaoTunel(emailSindico: widget.emailSindico), TelaConfiguracaoServidorLocal(emailSindico: widget.emailSindico)];
    } else {
      if (_temAcesso('encomendas')) { itensMenu.add({'icon': Icons.inventory_2, 'label': 'Encomendas', 'key': keyMenuEncomendas}); telas.add(widget.perfil == 'porteiro' ? TelaEncomendas(emailSindico: widget.emailSindico) : TelaEstoque(emailSindico: widget.emailSindico, perfil: widget.perfil)); }
      if (_temAcesso('estoque') && widget.perfil == 'porteiro') { itensMenu.add({'icon': Icons.grid_view, 'label': 'Estoque'}); telas.add(TelaEstoque(emailSindico: widget.emailSindico, perfil: widget.perfil)); }
      if (_temAcesso('visitantes')) { itensMenu.add({'icon': Icons.people_alt, 'label': 'Visitantes', 'key': keyMenuVisitantes}); telas.add(TelaVisitantes(emailSindico: widget.emailSindico, perfil: widget.perfil)); }
      if (_temAcesso('facial')) { itensMenu.add({'icon': Icons.face, 'label': 'Biometria Facial', 'key': keyMenuBiometria}); telas.add(TelaGestaoFacial(emailSindico: widget.emailSindico, perfil: widget.perfil)); }
      if (_temAcesso('cameras')) { itensMenu.add({'icon': Icons.videocam, 'label': 'Câmeras', 'key': keyMenuCameras}); telas.add(TelaCameras(emailSindico: widget.emailSindico, perfil: widget.perfil)); }
      if (_temAcesso('portoes')) { itensMenu.add({'icon': Icons.door_sliding, 'label': 'Portões', 'key': keyMenuPortoes}); telas.add(TelaPortoes(emailSindico: widget.emailSindico, perfil: widget.perfil)); }
      if (widget.perfil == 'porteiro' && (widget.menusPersonalizados['ronda_virtual'] ?? true)) { itensMenu.add({'icon': Icons.shield_moon, 'label': 'Ronda Virtual', 'key': keyMenuRonda}); telas.add(TelaRondaPortaria(emailSindico: widget.emailSindico)); }
      if (_temAcesso('reservas')) { itensMenu.add({'icon': Icons.event_available, 'label': 'Reservas', 'key': keyMenuReservas}); telas.add(TelaReservasAdmin(emailSindico: widget.emailSindico, perfil: widget.perfil)); }
      if (isSindico && _temAcesso('gestao')) { itensMenu.add({'icon': Icons.manage_accounts, 'label': 'Gestão', 'key': keyMenuGestao}); telas.add(TelaGestaoMoradores(emailSindico: widget.emailSindico)); if (widget.menusPersonalizados['ronda_gestao'] ?? true) { itensMenu.add({'icon': Icons.shield_moon, 'label': 'Rondas (Gestão)', 'key': GlobalKey()}); telas.add(TelaGestaoRondas(emailSindico: widget.emailSindico)); } }
      if (isSindico && widget.podeTrocarCondominio && (widget.menusPersonalizados['financeiro'] ?? true)) { itensMenu.add({'icon': Icons.request_quote, 'label': 'Financeiro (Admin)'}); telas.add(TelaCobrancasAdmin(emailSindico: widget.emailSindico)); }
      if (isSindico && !widget.podeTrocarCondominio && (widget.menusPersonalizados['despesas'] ?? true)) { itensMenu.add({'icon': Icons.money_off, 'label': 'Despesas do Mês'}); telas.add(TelaDespesasSindico(emailSindico: widget.emailSindico)); }
      if (widget.perfil == 'porteiro' && (widget.menusPersonalizados['anotacoes'] ?? true)) { itensMenu.add({'icon': Icons.push_pin, 'label': 'Anotações', 'key': keyMenuAnotacoes}); telas.add(TelaAnotacoesPortaria(emailSindico: widget.emailSindico)); }
      if (widget.menusPersonalizados['sobre'] ?? true) { itensMenu.add({'icon': Icons.info_outline, 'label': 'Sobre o Sistema', 'key': keyMenuSobre}); telas.add(const TelaSobreSistema()); }
      if (itensMenu.isEmpty) { itensMenu.add({'icon': Icons.block, 'label': 'Bloqueado'}); telas.add(const Center(child: Text("Nenhuma funcionalidade liberada no seu plano."))); }
    }
    _menuAtual = itensMenu;
    if (_index >= itensMenu.length) _index = 0;

    Widget buildNavMenu() => Column(children: [
      Card(elevation: 0, color: colorScheme.primaryContainer.withValues(alpha:0.5), margin: const EdgeInsets.only(bottom: 10, left: 8, right: 8, top: 8), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [GestureDetector(key: keyBotaoPanico, onLongPress: _dispararPanicoSilencioso, child: const Center(child: LogoLogicHome(size: 45))), const SizedBox(height: 15), FittedBox(fit: BoxFit.scaleDown, child: Text(isSindico ? "Administração" : (isTecnico ? "Central Técnica" : "Portaria"), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onPrimaryContainer), textAlign: TextAlign.center)), FittedBox(fit: BoxFit.scaleDown, child: Text("Op: $operadorLogado", style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center))]))),
      Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 10), itemCount: itensMenu.length, itemBuilder: (context, i) => Padding(padding: const EdgeInsets.only(bottom: 8.0), child: _index == i ? LogicNeonButton(fullWidth: true, onPressed: () {}, corBase: colorScheme.primary, child: Row(children: [Icon(itensMenu[i]['icon'], color: Colors.white, size: 20), const SizedBox(width: 10), Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(itensMenu[i]['label'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))))])) : InkWell(key: itensMenu[i]['key'], borderRadius: BorderRadius.circular(12), onTap: () { setState(() => _index = i); if (isMobile) Navigator.pop(context); }, child: Container(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24), decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest.withValues(alpha:0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: colorScheme.outlineVariant.withValues(alpha:0.5))), child: Row(children: [Icon(itensMenu[i]['icon'], color: colorScheme.onSurfaceVariant, size: 20), const SizedBox(width: 10), Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(itensMenu[i]['label'], style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 2))))])))))),
      SafeArea(top: false, child: StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('usuarios').doc(widget.emailSindico).snapshots(), builder: (context, snap) { if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())); if (snap.hasError || !snap.hasData || !snap.data!.exists) return const SizedBox.shrink(); final data = snap.data!.data() as Map<String, dynamic>; return Container(width: double.infinity, padding: const EdgeInsets.all(16), margin: const EdgeInsets.fromLTRB(8, 0, 8, 8), decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10), border: Border.all(color: colorScheme.primary.withValues(alpha:0.3))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [FittedBox(fit: BoxFit.scaleDown, child: Text(data['condominio'] ?? 'Condomínio', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center)), FittedBox(fit: BoxFit.scaleDown, child: Text("Síndico(a): ${data['nome']}", style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant.withValues(alpha:0.8)), textAlign: TextAlign.center)), if (!isTecnico) ...[Divider(color: colorScheme.onSurfaceVariant.withValues(alpha:0.2)), FittedBox(fit: BoxFit.scaleDown, child: Text("CÓDIGO DO CONDOMÍNIO:", style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant))), FittedBox(fit: BoxFit.scaleDown, child: Text(data['id_condominio'] ?? '----', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2, color: colorScheme.primary)))]])); }))
    ]);

    return Scaffold(
      appBar: AppBar(title: const Text("Logic Home"), actions:[if (!isTecnico) IconButton(key: keyBotaoAjuda, icon: const Icon(Icons.school, color: Colors.amberAccent), tooltip: "Central de Treinamento", onPressed: _abrirCentralDeTreinamento), if (widget.podeTrocarCondominio) IconButton(icon: Icon(Icons.maps_home_work, color: colorScheme.secondary), tooltip: "Voltar para Meus Condomínios", onPressed: () { GerenciadorDeTunel.desligarTudo(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TelaMeusCondominios())); }), if (!isTecnico && isSindico) IconButton(icon: Icon(Icons.workspace_premium, color: colorScheme.primary), tooltip: "Minha Assinatura SaaS", onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaMinhaAssinaturaSaaS(emailSindico: widget.emailSindico)))), if (!isTecnico && (widget.menusPersonalizados['avisos'] ?? true)) IconButton(icon: const Icon(Icons.notifications_active), tooltip: "Comunicados e Notificações", onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaNotificacoes(perfil: widget.perfil, emailUsuario: widget.emailSindico, emailSindico: widget.emailSindico)))), Container(key: keyTopTema, child: const BotaoTrocarTema()), IconButton(key: keyTopSair, icon: const Icon(Icons.logout), onPressed: () async { GerenciadorDeTunel.desligarTudo(); try { if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) { final token = await FirebaseMessaging.instance.getToken(); if (token != null) await FirebaseFirestore.instance.collection('usuarios').doc(FirebaseAuth.instance.currentUser!.email).update({'fcm_tokens': FieldValue.arrayRemove([token])}); } } catch (_) {} await HelperOffline.limparCofre(); await FirebaseAuth.instance.signOut(); if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const TelaLogin()), (_) => false); })]),
      drawer: isMobile ? Drawer(child: SafeArea(child: buildNavMenu())) : null,
      body: Row(children:[if (!isMobile) SizedBox(width: 280, child: buildNavMenu()), if (!isMobile) const VerticalDivider(width: 1), Expanded(child: Column(children: [if (isSindico) StreamBuilder<DocumentSnapshot>(stream: _infoCondominioStream, builder: (context, snap) { if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink(); final data = snap.data!.data() as Map<String, dynamic>; List<Widget> listaDeAlertas = []; if (data['transferencia_pendente'] != null) { final tf = data['transferencia_pendente']; listaDeAlertas.add(Container(width: double.infinity, padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 5), color: colorScheme.errorContainer, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.warning, color: colorScheme.onErrorContainer, size: 30), const SizedBox(width: 10), Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("⚠️ TRANSFERÊNCIA DE GESTÃO SOLICITADA", style: TextStyle(color: colorScheme.onErrorContainer, fontWeight: FontWeight.bold, fontSize: 16))))]), const SizedBox(height: 10), Text("A equipe Master iniciou o processo para transferir a titularidade deste condomínio para ${tf['novo_nome']} (${tf['novo_email']}). Ao confirmar, o novo síndico herdará todo o sistema, os moradores e os equipamentos, e você perderá o seu acesso imediatamente.", style: TextStyle(color: colorScheme.onErrorContainer)), const SizedBox(height: 15), _processandoTransferencia ? CircularProgressIndicator(color: colorScheme.onErrorContainer) : Wrap(spacing: 10, runSpacing: 10, children: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.onErrorContainer, foregroundColor: colorScheme.errorContainer), onPressed: () async { setState(() => _processandoTransferencia = true); await FirebaseFirestore.instance.collection('transferencias_gestao').doc(tf['log_id']).update({'status': 'recusada', 'data_conclusao': FieldValue.serverTimestamp()}); await snap.data!.reference.update({'transferencia_pendente': FieldValue.delete()}); setState(() => _processandoTransferencia = false); }, child: const Text("RECUSAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () async { setState(() => _processandoTransferencia = true); try { final res = await FirebaseService.criarUsuarioSaaS(email: tf['novo_email'], senha: (Random.secure().nextInt(900000) + 100000).toString(), nome: tf['novo_nome'], perfil: 'sindico', condominio: data['condominio'], idCondominio: data['id_condominio'], planoId: data['plano_id'] ?? '', dataExpiracao: data['data_expiracao'] != null ? (data['data_expiracao'] as Timestamp).toDate() : null, servicoAtivo: true, exigeTrocaSenha: true); if (res['sucesso'] != true) throw Exception(res['erro']); for (final col in ['usuarios', 'encomendas', 'portoes', 'cameras', 'idboxes', 'idfaces', 'visitantes', 'areas_comuns', 'reservas', 'fila_espera', 'notificacoes', 'auditoria', 'convites_vip', 'acessos_vip']) { final colSnap = await FirebaseFirestore.instance.collection(col).where('sindico_vinculado', isEqualTo: widget.emailSindico).get(); if (colSnap.docs.isNotEmpty) { int i = 0; while (i < colSnap.docs.length) { final batch = FirebaseFirestore.instance.batch(); final chunkEnd = (i + 500 < colSnap.docs.length) ? i + 500 : colSnap.docs.length; for (int j = i; j < chunkEnd; j++) { if (col == 'usuarios' && colSnap.docs[j].id == tf['novo_email']) continue; batch.update(colSnap.docs[j].reference, {'sindico_vinculado': tf['novo_email']}); } await batch.commit(); i += 500; } } } await FirebaseFirestore.instance.collection('transferencias_gestao').doc(tf['log_id']).update({'status': 'aprovada', 'data_conclusao': FieldValue.serverTimestamp()}); await snap.data!.reference.delete(); GerenciadorDeTunel.desligarTudo(); await FirebaseAuth.instance.signOut(); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Transferência concluída! O novo síndico deve usar a opção 'Esqueci minha senha' para criar seu acesso."), backgroundColor: Colors.green, duration: Duration(seconds: 8))); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TelaLogin())); } } catch (e) { setState(() => _processandoTransferencia = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: colorScheme.error)); } }, child: const Text("CONFIRMAR E TRANSFERIR"))])]))); } if (data['pedido_administradora'] != null) { final ped = data['pedido_administradora']; listaDeAlertas.add(Container(width: double.infinity, padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 5), color: colorScheme.secondaryContainer, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.handshake, color: colorScheme.onSecondaryContainer, size: 30), const SizedBox(width: 10), Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("SOLICITAÇÃO DE VÍNCULO (ADMINISTRADORA)", style: TextStyle(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold, fontSize: 16))))]), const SizedBox(height: 10), Text("A Administradora/Empresa ${ped['nome_admin']} (${ped['email_admin']}) solicitou acesso ao sistema para realizar a gestão deste condomínio. Ao confirmar, eles terão acesso de síndico.", style: TextStyle(color: colorScheme.onSecondaryContainer.withValues(alpha:0.8))), const SizedBox(height: 15), _processandoTransferencia ? CircularProgressIndicator(color: colorScheme.onSecondaryContainer) : Wrap(spacing: 10, runSpacing: 10, children: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError), onPressed: () async { setState(() => _processandoTransferencia = true); await snap.data!.reference.update({'pedido_administradora': FieldValue.delete()}); setState(() => _processandoTransferencia = false); }, child: const Text("RECUSAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () async { setState(() => _processandoTransferencia = true); try { await snap.data!.reference.update({'pedido_administradora': FieldValue.delete(), 'administradora_vinculada': ped['email_admin']}); await FirebaseFirestore.instance.collection('usuarios').doc(ped['email_admin']).update({'condominios_gerenciados': FieldValue.arrayUnion([widget.emailSindico])}); await registrarAuditoria(widget.emailSindico, "Vínculo com Administradora Aprovado", "Gestão", "O síndico autorizou o acesso da administradora ${ped['email_admin']}."); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Administradora vinculada com sucesso!"), backgroundColor: Colors.green)); setState(() => _processandoTransferencia = false); } catch (e) { setState(() => _processandoTransferencia = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); } }, child: const Text("CONFIRMAR E AUTORIZAR"))])]))); } if (data['url_fatura_atual'] != null && data['url_fatura_atual'].toString().isNotEmpty && data['status_fatura'] != 'PAGA') { final licencaExpirada = data['data_expiracao'] != null && (data['data_expiracao'] as Timestamp).toDate().isBefore(DateTime.now()); listaDeAlertas.add(Container(width: double.infinity, padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 5), color: colorScheme.errorContainer, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(licencaExpirada ? Icons.lock : Icons.payment, color: colorScheme.onErrorContainer, size: 30), const SizedBox(width: 10), Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(licencaExpirada ? "SISTEMA BLOQUEADO - MENSALIDADE VENCIDA" : "MENSALIDADE DISPONÍVEL PARA PAGAMENTO", style: TextStyle(color: colorScheme.onErrorContainer, fontWeight: FontWeight.bold, fontSize: 16))))]), const SizedBox(height: 10), Text(licencaExpirada ? "O seu acesso às funções de gestão foi bloqueado. Realize o pagamento clicando no botão abaixo para a liberação automática do sistema." : "A fatura de renovação do seu plano SaaS foi gerada. Evite o bloqueio do sistema e a suspensão dos serviços de portaria.", style: TextStyle(color: colorScheme.onErrorContainer.withValues(alpha:0.8))), const SizedBox(height: 15), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.onErrorContainer, foregroundColor: colorScheme.errorContainer), icon: const Icon(Icons.receipt_long), label: const Text("ABRIR FATURA"), onPressed: () async { final url = Uri.parse(data['url_fatura_atual']); if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication); else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não foi possível abrir a fatura."))); })]))); } return listaDeAlertas.isEmpty ? const SizedBox.shrink() : Column(children: listaDeAlertas); }), Expanded(child: StreamBuilder<DocumentSnapshot>(stream: _infoCondominioStream, builder: (context, snapBlock) { if (snapBlock.hasData && snapBlock.data!.exists && (snapBlock.data!.data() as Map<String, dynamic>)['servico_ativo'] != true) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_outline, size: 100, color: Theme.of(context).colorScheme.error.withValues(alpha:0.5)), const SizedBox(height: 20), Text("SISTEMA BLOQUEADO", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error)), const SizedBox(height: 10), const Text("O acesso às funções foi suspenso. Utilize o banner superior para regularizar.", style: TextStyle(color: Colors.grey))])); return AnimatedSwitcher(duration: const Duration(milliseconds: 300), switchInCurve: Curves.easeIn, switchOutCurve: Curves.easeOut, transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child), child: Container(key: ValueKey<int>(_index), child: telas[_index])); }))]))]),
    );
  }
}

class TelaMorador extends StatefulWidget {
  final Map<String, dynamic> userData;
  final int abaInicial;
  const TelaMorador({super.key, required this.userData, this.abaInicial = 0});
  @override
  State<TelaMorador> createState() => _TelaMoradorState();
}

class _TelaMoradorState extends State<TelaMorador> with WidgetsBindingObserver {
  int _abaAtual = 0;
  int _limiteNotificacoesMorador = 20;
  late Stream<QuerySnapshot> _minhasEncomendasStream, _meuPedidoDeliveryStream;
  late Stream<DocumentSnapshot> _regrasSindicoStream;
  StreamSubscription<DocumentSnapshot>? _sessaoSub;

  int _calcularIdadeMorador() {
    String? nasc = widget.userData['data_nascimento'];
    if (nasc == null || nasc.isEmpty) return 99; // Se não preencheu, assume adulto para não travar
    try {
      final partes = nasc.split('/');
      DateTime dtNasc = DateTime(int.parse(partes[2]), int.parse(partes[1]), int.parse(partes[0]));
      DateTime hoje = DateTime.now();
      int idade = hoje.year - dtNasc.year;
      if (hoje.month < dtNasc.month || (hoje.month == dtNasc.month && hoje.day < dtNasc.day)) idade--;
      return idade;
    } catch (_) { return 99; }
  }
  StreamSubscription<QuerySnapshot>? _notificacoesSub; 
  List<Map<String, dynamic>> _avisosLocais = [];
  bool _carregandoAvisos = true, _temInternet = true;
  Timer? _heartbeatTimer, _internetTimer;

  @override
  void initState() {
    super.initState();
    _abaAtual = widget.abaInicial;
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 10), (_) async { try { await FirebaseAuth.instance.currentUser?.getIdToken(true); } catch (_) {} });
    _verificarInternet();
    _internetTimer = Timer.periodic(const Duration(seconds: 3), (_) => _verificarInternet());
    WidgetsBinding.instance.addObserver(this);
    _initStreams(); 
    _sincronizarPortoesOffline();
    if (widget.userData['status'] == 'aprovado' || widget.userData['servico_ativo'] == true) {
      _configurarPushNotifications(widget.userData['email']);
      RadarBluetooth.ligarRadar();
    }
  }

  Future<void> _sincronizarPortoesOffline() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('portoes').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('permite_morador', isEqualTo: true).get();
      if (snap.docs.isNotEmpty) await HelperOffline.salvarPortoesNoCofre(snap.docs.map((d) => d.data()..['id_portao'] = d.id).toList());
    } catch (_) {}
  }

  Future<void> _verificarInternet() async {
    // Ignora o teste se o aplicativo estiver minimizado para não dar falso positivo por economia de bateria
    if (WidgetsBinding.instance.lifecycleState != null && WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;

    bool online = true;
    if (!kIsWeb) {
      try {
        if ((await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2))).isEmpty) online = false;
      } catch (_) { online = false; }
    }
    
    if (!mounted) return;
    if (_temInternet && !online) {
      setState(() => _temInternet = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Conexão perdida! Você foi levado para o Modo Offline."), backgroundColor: Colors.orange));
    } else if (!_temInternet && online) {
      try {
        await FirebaseAuth.instance.currentUser?.reload();
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("Sessão expirada");
        final docUser = await FirebaseFirestore.instance.collection('usuarios').doc(user.email).get(const GetOptions(source: Source.server));
        if (!docUser.exists) throw Exception("Usuário removido");
        final data = docUser.data()!;
        if (data['status'] != 'aprovado' || data['servico_ativo'] != true || data['sindico_vinculado'] != widget.userData['sindico_vinculado']) throw Exception("Acesso bloqueado pela administração");
        setState(() { _temInternet = true; _initStreams(); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Internet restabelecida! Reconectado com sucesso."), backgroundColor: Colors.green));
      } catch (e) {
        _internetTimer?.cancel();
        await FirebaseAuth.instance.signOut();
        await (await SharedPreferences.getInstance()).remove('off_user_data');
        await (await SharedPreferences.getInstance()).remove('off_senha');
        if (globalNavigatorKey.currentContext != null) {
          Navigator.pushAndRemoveUntil(globalNavigatorKey.currentContext!, MaterialPageRoute(builder: (_) => const TelaLogin()), (_) => false);
          showDialog(context: globalNavigatorKey.currentContext!, barrierDismissible: false, builder: (c) => AlertDialog(title: const Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 10), Text("Acesso Negado")]), content: const Text("Seu acesso foi revogado ou alterado pela administração. Entre em contato com a Portaria/Síndico."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("FECHAR"))]));
        }
      }
    }
  }

  void _initStreams() {
    _regrasSindicoStream = FirebaseFirestore.instance.collection('usuarios').doc(widget.userData['sindico_vinculado']).snapshots();
    _minhasEncomendasStream = FirebaseFirestore.instance.collection('encomendas').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('bloco', isEqualTo: widget.userData['bloco']).where('ap', isEqualTo: widget.userData['ap']).snapshots();
    final meuEmail = widget.userData['email'].toString().toLowerCase().trim();
    
    Future<void> carregarMuralDeAvisos() async {
      var queryBase = FirebaseFirestore.instance.collection('notificacoes')
          .where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado'])
          .where('para', whereIn: ['todos', meuEmail])
          .orderBy('data', descending: true)
          .limit(_limiteNotificacoesMorador); // Aplica o limite dinâmico (20, 40, 60...)

      try {
        final snapCache = await queryBase.get(const GetOptions(source: Source.cache));
        if (mounted) setState(() { _avisosLocais = snapCache.docs.map((d) => d.data()..['id'] = d.id).toList(); });
      } catch (_) {
        if (mounted) setState(() { _avisosLocais = []; });
      }

      _notificacoesSub?.cancel();
      final momentoConexao = DateTime.now();
      
      _notificacoesSub = queryBase.snapshots().listen((snapNuvem) {
        if (snapNuvem.docs.isEmpty) {
          if (mounted && _carregandoAvisos) setState(() => _carregandoAvisos = false);
          return;
        }
        
        // O Firebase já gerencia o cache e devolve a lista perfeita na ordem certa
        _avisosLocais = snapNuvem.docs.map((d) => d.data() as Map<String, dynamic>..['id'] = d.id).toList();

        // Passa um "pente fino" apenas para saber se tem que apitar notificação na tela
        for (var change in snapNuvem.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>;
            if (data['data'] != null && (data['data'] as Timestamp).toDate().isAfter(momentoConexao)) {
              flutterLocalNotificationsPlugin?.show(change.doc.id.hashCode, data['titulo'], data['mensagem'], const NotificationDetails(android: AndroidNotificationDetails('logic_home_channel', 'Avisos e Entregas', importance: Importance.max, priority: Priority.high, color: Color(0xFF00E5FF), playSound: true, enableVibration: true), iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)), payload: data['tipo_acao'] ?? 'acao_avisos');
            }
          }
        }
        
        if (mounted) setState(() => _carregandoAvisos = false);
      }, onError: (e) {
         if (mounted) setState(() => _carregandoAvisos = false);
      });
    }

    carregarMuralDeAvisos();
    _meuPedidoDeliveryStream = FirebaseFirestore.instance.collection('esperando_delivery').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('email', isEqualTo: widget.userData['email']).snapshots();
    _sessaoSub?.cancel(); 
    _sessaoSub = FirebaseFirestore.instance.collection('usuarios').doc(widget.userData['email']).snapshots().listen((docSnap) async {
      if (docSnap.exists) {
        final newData = docSnap.data() as Map<String, dynamic>;
        if (pulseiraDaSessao.isNotEmpty && !(newData['sessoes_ativas'] ?? []).contains(pulseiraDaSessao)) {
          FirebaseAuth.instance.signOut();
          if (mounted) { Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const TelaLogin()), (_) => false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sessão expirada. Você fez login em outro dispositivo."), backgroundColor: Colors.red, duration: Duration(seconds: 5))); }
        } else if (newData['foto_storage_url'] != widget.userData['foto_storage_url']) {
          if (!kIsWeb) {
            try {
              final file = File('${(await getApplicationDocumentsDirectory()).path}/minha_foto_${widget.userData['email']}.jpg');
              if (await file.exists()) await file.delete();
            } catch (_) {}
          }
          if (mounted) {
            setState(() { widget.userData['foto_storage_url'] = newData['foto_storage_url']; });
          }
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) FirebaseAuth.instance.currentUser?.getIdToken(true); }

  Future<void> _configurarPushNotifications(String emailUsuario) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) return;
    try {
      final messaging = FirebaseMessaging.instance;
      if ((await messaging.requestPermission(alert: true, badge: true, sound: true)).authorizationStatus == AuthorizationStatus.authorized) {
        final token = await messaging.getToken();
        if (token != null) await FirebaseFirestore.instance.collection('usuarios').doc(emailUsuario).update({'fcm_tokens': FieldValue.arrayUnion([token])});
        messaging.onTokenRefresh.listen((nt) => FirebaseFirestore.instance.collection('usuarios').doc(emailUsuario).update({'fcm_tokens': FieldValue.arrayUnion([nt])}));
        if (defaultTargetPlatform == TargetPlatform.android) await flutterLocalNotificationsPlugin?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(const AndroidNotificationChannel('canal_panico_absoluto_v10', 'Emergências e Pânico', description: 'Alarmes de pânico da portaria', importance: Importance.max, playSound: true, sound: RawResourceAndroidNotificationSound('sirene'), enableVibration: true, audioAttributesUsage: AudioAttributesUsage.alarm));
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          if (message.data['eh_panico'] == "true") {
            if (globalNavigatorKey.currentState != null) globalNavigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => const TelaPanicoAlarme()));
            flutterLocalNotificationsPlugin?.show(message.hashCode, message.data['title'], message.data['body'], const NotificationDetails(android: AndroidNotificationDetails('canal_panico_absoluto_v10', 'Emergências e Pânico', importance: Importance.max, priority: Priority.max, color: Colors.red, sound: RawResourceAndroidNotificationSound('sirene'), playSound: true, enableVibration: true, fullScreenIntent: true, audioAttributesUsage: AudioAttributesUsage.alarm, category: AndroidNotificationCategory.alarm), iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true, sound: 'sirene.mp3', interruptionLevel: InterruptionLevel.critical)), payload: 'panico');
          }
        });
      }
    } catch (e) { debugPrint("Erro ao configurar notificações push: $e"); }
  }

  @override
  void dispose() { _heartbeatTimer?.cancel(); _internetTimer?.cancel(); WidgetsBinding.instance.removeObserver(this); _sessaoSub?.cancel(); _notificacoesSub?.cancel(); super.dispose(); }

  void _atualizarDadosMorador() {
    String novoTelefone = widget.userData['telefone'] ?? '', novoBloco = widget.userData['bloco'] ?? '', novoAp = widget.userData['ap'] ?? '', novoCodigoCondominio = '';
    int modoEdicao = 0; 
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Atualizar Minha Conta")),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [ChoiceChip(label: const Text("Meu Condomínio"), selected: modoEdicao == 0, onSelected: (v) => setStateSB(() => modoEdicao = 0)), ChoiceChip(label: const Text("Mudar Condomínio"), selected: modoEdicao == 1, onSelected: (v) => setStateSB(() => modoEdicao = 1), selectedColor: colorScheme.secondaryContainer)]), const SizedBox(height: 20),
            TextField(controller: TextEditingController(text: novoTelefone), onChanged: (v) => novoTelefone = v, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefone de Contato", border: OutlineInputBorder())), const SizedBox(height: 15),
            if (modoEdicao == 0) ...[const Text("Deseja mudar de apartamento?", style: TextStyle(color: Colors.grey)), const SizedBox(height: 10), Row(children: [Expanded(child: TextField(controller: TextEditingController(text: novoBloco), onChanged: (v) => novoBloco = v.toUpperCase(), decoration: const InputDecoration(labelText: "Novo Bloco", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(controller: TextEditingController(text: novoAp), onChanged: (v) => novoAp = v, decoration: const InputDecoration(labelText: "Novo AP", border: OutlineInputBorder())))])] else ...[Text("Para mudar de condomínio, informe o novo ID fornecido pelo Síndico:", style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.bold)), const SizedBox(height: 10), TextField(onChanged: (v) => novoCodigoCondominio = v.trim(), decoration: const InputDecoration(labelText: "Código do Novo Condomínio", border: OutlineInputBorder())), const SizedBox(height: 10), Row(children: [Expanded(child: TextField(onChanged: (v) => novoBloco = v.toUpperCase(), decoration: const InputDecoration(labelText: "Novo Bloco", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(onChanged: (v) => novoAp = v, decoration: const InputDecoration(labelText: "Novo AP", border: OutlineInputBorder())))])],
            const SizedBox(height: 10), Text("Atenção: Qualquer alteração bloqueará seu acesso até que a administração aprove a mudança.", style: TextStyle(color: colorScheme.error, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ]),
        ),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          LogicNeonButton(corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: () async {
            if (novoTelefone.isEmpty || novoBloco.isEmpty || novoAp.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos!"))); return; }
            
            showDialog(context: context, barrierDismissible: false, builder: (c) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 15), Text("Verificando pacotes na portaria...")])));
            try {
              final pacotesPendentes = await FirebaseFirestore.instance.collection('encomendas').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('bloco', isEqualTo: widget.userData['bloco']).where('ap', isEqualTo: widget.userData['ap']).where('status', whereIn: ['aguardando', 'em_retirada']).get();
              if (pacotesPendentes.docs.isNotEmpty) { if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Você possui pacotes na portaria! Retire-os antes de mudar de endereço."), backgroundColor: Colors.red, duration: Duration(seconds: 8))); } return; }
              if (mounted) Navigator.pop(context); 
            } catch (_) { if (mounted) Navigator.pop(context); }

            String sindicoVinculadoFinal = widget.userData['sindico_vinculado'];
            if (modoEdicao == 1) {
              if (novoCodigoCondominio.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Informe o Código do Condomínio!"))); return; }
              final sindicoQuery = await FirebaseFirestore.instance.collection('usuarios').where('perfil', isEqualTo: 'sindico').where('id_condominio', isEqualTo: novoCodigoCondominio).get();
              if (sindicoQuery.docs.isEmpty) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Código de condomínio inválido!"), backgroundColor: colorScheme.error)); return; }
              sindicoVinculadoFinal = sindicoQuery.docs.first.id;
            }
            try { if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) { final token = await FirebaseMessaging.instance.getToken(); if (token != null) await FirebaseFirestore.instance.collection('usuarios').doc(widget.userData['email']).update({'fcm_tokens': FieldValue.arrayRemove([token])}); } } catch (_) {}
            await FirebaseFirestore.instance.collection('usuarios').doc(widget.userData['email']).update({'telefone': novoTelefone, 'bloco': novoBloco, 'ap': novoAp, 'sindico_vinculado': sindicoVinculadoFinal, 'status': 'pendente', 'servico_ativo': false});
            if (mounted) { Navigator.pop(ctx); }
            await FirebaseAuth.instance.signOut();
            if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dados enviados para aprovação!"), backgroundColor: Colors.green)); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TelaLogin())); }
          }, child: const Text("ENVIAR", style: TextStyle(color: Colors.white)))
        ],
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final isPendente = widget.userData['status'] == 'pendente', colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(leading: (_abaAtual != 0 && !isPendente && _temInternet) ? IconButton(icon: const Icon(Icons.arrow_back), tooltip: "Voltar ao Início", onPressed: () => setState(() => _abaAtual = 0)) : null, title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Logic Home", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), InkWell(onTap: () => showDialog(context: context, builder: (ctx) => const CardSobreLogicHome(isDialog: true)), child: Text("Sobre o sistema", style: TextStyle(fontSize: 11, color: colorScheme.primary, decoration: TextDecoration.underline)))]), actions:[IconButton(icon: const Icon(Icons.manage_accounts), onPressed: _atualizarDadosMorador), const BotaoTrocarTema(), IconButton(icon: const Icon(Icons.logout), onPressed: () async { try { if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) { final token = await FirebaseMessaging.instance.getToken(); if (token != null) await FirebaseFirestore.instance.collection('usuarios').doc(widget.userData['email']).update({'fcm_tokens': FieldValue.arrayRemove([token])}); } } catch (_) {} await HelperOffline.limparCofre(); await FirebaseAuth.instance.signOut(); if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const TelaLogin()), (_) => false); }, tooltip: "Sair")]),
      body: !_temInternet ? _buildTelaApenasBluetooth() : (isPendente ? _buildTelaPendente() : _buildCorpoApp()),
      bottomNavigationBar: (!_temInternet || isPendente) ? null : BottomNavigationBar(currentIndex: (_abaAtual == 3) ? 1 : (_abaAtual == 6 ? 2 : 0), onTap: (index) { if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) HapticFeedback.selectionClick(); setState(() { if (index == 0) _abaAtual = 0; else if (index == 1) _abaAtual = 3; else if (index == 2) _abaAtual = 6; }); }, type: BottomNavigationBarType.fixed, selectedItemColor: colorScheme.primary, unselectedItemColor: colorScheme.onSurfaceVariant, backgroundColor: colorScheme.surface, items: const[BottomNavigationBarItem(icon: Icon(Icons.home), label: "Início"), BottomNavigationBarItem(icon: Icon(Icons.event), label: "Reservas"), BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Avisos")]),
    );
  }

  Widget _buildTelaApenasBluetooth() => Column(children: [
    Container(width: double.infinity, padding: const EdgeInsets.all(15), color: Colors.red.shade900, child: const SafeArea(bottom: false, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.wifi_off, color: Colors.white), SizedBox(width: 10), Text("MODO OFFLINE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2))]))),
    const Padding(padding: EdgeInsets.all(20.0), child: Text("Sem conexão com a internet.\nO sistema foi bloqueado por segurança, mas você ainda pode abrir os portões via Bluetooth.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14))),
    Expanded(child: FutureBuilder<QuerySnapshot>(future: FirebaseFirestore.instance.collection('portoes').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('permite_morador', isEqualTo: true).get(const GetOptions(source: Source.cache)), builder: (context, snap) {
      if (snap.hasError) return const Center(child: Text("Erro ao ler memória offline.", style: TextStyle(color: Colors.white)));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhum portão disponível na memória."));
      HelperOffline.salvarPortoesNoCofre(snap.data!.docs.map((d) => (d.data() as Map<String, dynamic>)..['id_portao'] = d.id).toList());
      return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: snap.data!.docs.length, itemBuilder: (context, i) { final data = snap.data!.docs[i].data() as Map<String, dynamic>; return Card(margin: const EdgeInsets.only(bottom: 15), shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.blue, width: 2), borderRadius: BorderRadius.circular(15)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.bluetooth, color: Colors.white)), title: Text(data['nome'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), trailing: LogicNeonButton(corBase: Colors.blue.shade800, corBrilho: Colors.lightBlueAccent, onPressed: () => _abrirPortaoMorador(data, snap.data!.docs[i].id, usarBluetooth: true), child: const Text("ABRIR", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))))); });
    }))
  ]);

  Widget _buildTelaPendente() => Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.hourglass_empty, size: 80, color: Theme.of(context).colorScheme.secondary), const SizedBox(height: 20), const FittedBox(fit: BoxFit.scaleDown, child: Text("Cadastro em Análise", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))), const SizedBox(height: 10), Text("Seu cadastro foi recebido e está aguardando aprovação da administração.", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16))])));

  Widget _buildCorpoApp() => AnimatedSwitcher(duration: const Duration(milliseconds: 300), switchInCurve: Curves.easeIn, switchOutCurve: Curves.easeOut, transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child), child: Container(key: ValueKey<int>(_abaAtual), child: _abaAtual == 0 ? _abaInicio() : (_abaAtual == 1 ? _abaConvites() : (_abaAtual == 2 ? _abaEncomendas() : (_abaAtual == 3 ? TelaReservasMorador(userData: widget.userData) : (_abaAtual == 4 ? _abaInterfonia() : (_abaAtual == 5 ? _abaFinanceiroMorador() : _abaAvisos())))))));

  Future<File?> _obterFotoLocal() async {
    if (widget.userData['foto_storage_url'] == null || kIsWeb) return null;
    final file = File('${(await getApplicationDocumentsDirectory()).path}/minha_foto_${widget.userData['email']}.jpg');
    if (await file.exists()) return file;
    try { final res = await http.get(Uri.parse(widget.userData['foto_storage_url'])); if (res.statusCode == 200) { await file.writeAsBytes(res.bodyBytes); return file; } } catch(_) {}
    return null;
  }

  Widget _abaInicio() {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Wrap(spacing: 15, crossAxisAlignment: WrapCrossAlignment.center, children: [FutureBuilder<File?>(future: _obterFotoLocal(), builder: (context, snapFoto) { return Container(width: 70, height: 70, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, shape: BoxShape.circle, border: Border.all(color: colorScheme.primary.withValues(alpha:0.5), width: 2), image: snapFoto.hasData ? DecorationImage(image: FileImage(snapFoto.data!), fit: BoxFit.cover) : (widget.userData['foto_storage_url'] != null && kIsWeb ? DecorationImage(image: NetworkImage(widget.userData['foto_storage_url']), fit: BoxFit.cover) : null)), child: widget.userData['foto_storage_url'] == null ? Icon(Icons.face, size: 30, color: colorScheme.onSurfaceVariant) : null); }), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [FittedBox(fit: BoxFit.scaleDown, child: Text("Olá, ${widget.userData['nome']}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, child: Text("Bloco ${widget.userData['bloco']} | AP ${widget.userData['ap']}", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16)))])]), const SizedBox(height: 30),
      StreamBuilder<QuerySnapshot>(stream: _meuPedidoDeliveryStream, builder: (context, snapDelivery) {
        bool temPedidosAtivos = snapDelivery.hasData && snapDelivery.data!.docs.isNotEmpty;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LogicNeonButton(fullWidth: true, corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: () {
            String descricaoLocal = "";
            showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
              return AlertDialog(title: const Text("Avisar a Portaria"), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Use isto para entregas rápidas (comida, farmácia, etc).", style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 15), TextField(onChanged: (v) => descricaoLocal = v, decoration: const InputDecoration(labelText: "Aplicativo/Local (Ex: iFood, Farmácia)", border: OutlineInputBorder()), textCapitalization: TextCapitalization.words, autofocus: true)]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))), LogicNeonButton(corBase: Colors.orange.shade800, corBrilho: Colors.orangeAccent, onPressed: () async { if (descricaoLocal.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Digite de onde vem a entrega!"))); return; } try { String emailSeguro = FirebaseAuth.instance.currentUser?.email ?? widget.userData['email'] ?? ''; if (emailSeguro.isEmpty) throw Exception("E-mail não encontrado na sessão."); await FirebaseFirestore.instance.collection('esperando_delivery').add({'sindico_vinculado': widget.userData['sindico_vinculado'], 'email': emailSeguro, 'nome': widget.userData['nome'] ?? 'Morador', 'bloco': widget.userData['bloco'] ?? '', 'ap': widget.userData['ap'] ?? '', 'descricao': descricaoLocal.trim(), 'data_hora': FieldValue.serverTimestamp()}); if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A portaria foi avisada!"), backgroundColor: Colors.green)); } } catch (e) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); } } }, child: const Text("AVISAR PORTARIA", style: TextStyle(color: Colors.white, fontSize: 12)))]);
            }));
          }, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const FittedBox(fit: BoxFit.scaleDown, child: Text("Vou receber Delivery", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))), const SizedBox(height: 5), FittedBox(fit: BoxFit.scaleDown, child: Text("Avisar portaria sobre entrega rápida", style: TextStyle(color: Colors.white.withValues(alpha:0.8), fontSize: 12, letterSpacing: 0)))])), const Icon(Icons.fastfood, color: Colors.white, size: 30)])),
          if (temPedidosAtivos) ...[const SizedBox(height: 15), const Text("Avisos enviados para a portaria:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 5), ...snapDelivery.data!.docs.map((doc) => Card(color: colorScheme.surfaceContainerHighest, margin: const EdgeInsets.only(bottom: 5), child: ListTile(dense: true, leading: const Icon(Icons.access_time, color: Colors.orange), title: Text((doc.data() as Map<String, dynamic>)['descricao'] ?? 'Delivery Rápido', style: const TextStyle(fontWeight: FontWeight.bold)), trailing: IconButton(icon: Icon(Icons.cancel, color: colorScheme.error), tooltip: "Cancelar este aviso", onPressed: () async { await doc.reference.delete(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aviso removido."))); }))))]
        ]);
      }), const SizedBox(height: 15),
      LogicNeonButton(fullWidth: true, corBase: colorScheme.secondary, corBrilho: colorScheme.secondary, onPressed: () => setState(() => _abaAtual = 1), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const FittedBox(fit: BoxFit.scaleDown, child: Text("Convite Expresso", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))), const SizedBox(height: 5), FittedBox(fit: BoxFit.scaleDown, child: Text("Gerar Link para Visita", style: TextStyle(color: Colors.white.withValues(alpha:0.8), fontSize: 12, letterSpacing: 0)))])), const Icon(Icons.insert_link, color: Colors.white, size: 30)])), const SizedBox(height: 20), const Text("Atalhos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
      Row(children: [Expanded(child: _cardAtalho(Icons.inventory_2, "Pacotes", colorScheme.primary, () => setState(() => _abaAtual = 2))), const SizedBox(width: 15), Expanded(child: _cardAtalho(Icons.door_sliding, "Portões", colorScheme.primary, () => setState(() => _abaAtual = 4))), const SizedBox(width: 15), Expanded(child: _cardAtalho(Icons.request_quote, "Faturas", colorScheme.primary, () => setState(() => _abaAtual = 5)))])
    ]);
  }

  Widget _cardAtalho(IconData icone, String titulo, Color cor, VoidCallback onPressed) => LogicNeonButton(corBase: cor.withValues(alpha:0.8), corBrilho: cor, onPressed: onPressed, child: Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icone, size: 40, color: Colors.white), const SizedBox(height: 10), FittedBox(fit: BoxFit.scaleDown, child: Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))])));

  Future<String> _tentarBluetoothOculto(String macApp, String rele) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) return "ERR";
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final statuses = await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse].request();
        if (statuses[Permission.bluetoothConnect]!.isPermanentlyDenied || statuses[Permission.bluetoothScan]!.isPermanentlyDenied) { openAppSettings(); return "ERR"; }
      }
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        if (defaultTargetPlatform == TargetPlatform.android) try { await FlutterBluePlus.turnOn(); } catch (_) {}
        try { await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first.timeout(const Duration(seconds: 5)); } catch (_) { return "ERR"; }
      }
      try { await FlutterBluePlus.stopScan(); } catch(_) {}
      await Future.delayed(const Duration(milliseconds: 500));

      final completer = Completer<String>();
      bool conectando = false;
      final subscription = FlutterBluePlus.scanResults.listen((results) async {
        if (conectando) return;
        for (final r in results) {
          final nome = r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName;
          if (nome.contains("PORTAO") || r.advertisementData.serviceUuids.any((uuid) => uuid.toString().toLowerCase() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b")) {
            conectando = true;
            try { await FlutterBluePlus.stopScan(); } catch(_) {}
            try {
              await r.device.connect(timeout: const Duration(seconds: 10), autoConnect: false);
              if (defaultTargetPlatform == TargetPlatform.android) try { await r.device.requestMtu(512); } catch(_) {}
              await Future.delayed(const Duration(milliseconds: 500));
              for (final service in await r.device.discoverServices()) {
                if (service.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
                  for (final c in service.characteristics) {
                    if (c.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
                      try { await c.setNotifyValue(true); } catch (_) {}
                      final comandoSeguro = "SEC|${Uri.encodeComponent(CryptoHelper.criptografar("${widget.userData['email'] ?? ''};${DateTime.now().millisecondsSinceEpoch};ONL"))}|$rele";
                      bool resolvido = false; String statusFinal = "TIMEOUT";
                      final notifySub = c.onValueReceived.listen((value) async {
                        final rep = utf8.decode(value);
                        if (rep == "OK") { resolvido = true; statusFinal = "OK"; } else if (rep == "BLKD") { resolvido = true; statusFinal = "BLKD"; if (globalNavigatorKey.currentContext != null) { final prefs = await SharedPreferences.getInstance(); await prefs.remove('off_user_data'); await prefs.remove('off_senha'); await FirebaseAuth.instance.signOut(); Navigator.pushAndRemoveUntil(globalNavigatorKey.currentContext!, MaterialPageRoute(builder: (_) => const TelaLogin()), (_) => false); showDialog(context: globalNavigatorKey.currentContext!, barrierDismissible: false, builder: (c) => AlertDialog(title: const Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 10), Text("Acesso Negado")]), content: const Text("Você não tem permissão da administração para abrir o portão. Entre em contato com a Portaria para resolver sua situação."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("FECHAR"))])); } } else if (rep == "ERR") { resolvido = true; statusFinal = "ERR"; } else if (rep == "MOV") { resolvido = true; statusFinal = "MOV"; }
                      });
                      try { await c.write(utf8.encode(comandoSeguro), withoutResponse: false); } catch (_) {}
                      for (int i = 0; i < 15; i++) { await Future.delayed(const Duration(milliseconds: 500)); if (resolvido) break; }
                      notifySub.cancel(); await r.device.disconnect(); if (!completer.isCompleted) completer.complete(statusFinal);
                      return;
                    }
                  }
                }
              }
              await r.device.disconnect();
            } catch (_) {}
            if (!completer.isCompleted) completer.complete("ERR"); return;
          }
        }
      });
      try { await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6)); } catch(_) {}
      final resultado = await completer.future.timeout(const Duration(seconds: 8), onTimeout: () => "TIMEOUT");
      subscription.cancel(); try { await FlutterBluePlus.stopScan(); } catch(_) {}
      return resultado;
    } catch (_) { return "ERR"; }
  }

  void _abrirPortaoMorador(Map<String, dynamic> dataPortao, String idPortao, {bool usarBluetooth = false}) async {
    mostrarBrilhoNeon(context);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(usarBluetooth ? "Conectando via Bluetooth..." : "Enviando comando..."), duration: const Duration(seconds: 1)));
    
    if (usarBluetooth) {
      final statusBle = await _tentarBluetoothOculto(dataPortao['id_box'], dataPortao['codigo']);
      if (statusBle == "OK") {
        registrarAuditoria(widget.userData['sindico_vinculado'], "Abertura Bluetooth", "Acesso Mobile", "Portão ${dataPortao['nome']} acionado localmente por ${widget.userData['nome']}.").catchError((_) {});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Portão abrindo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
      } else if (statusBle == "MOV") {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text("Aguarde! Portão já está em movimento.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Portão fora de alcance Bluetooth.")));
      }
      return; 
    }

    bool temInternet = true;
    if (!kIsWeb) { 
      try { if ((await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2))).isEmpty) temInternet = false; } catch (_) { temInternet = false; }
    }
    if (!temInternet) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text("Sem internet. Use o botão de Bluetooth ao lado.", style: TextStyle(color: Colors.white)), duration: Duration(seconds: 4))); return; }
    
    final tempoAbertura = dataPortao['tempo_abertura'] ?? 15;
    if (dataPortao['ultima_abertura'] != null && DateTime.now().difference((dataPortao['ultima_abertura'] as Timestamp).toDate()).inSeconds.abs() < tempoAbertura) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text("Aguarde! Portão já está em movimento.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
      return;
    }
    try {
      final docAtual = await FirebaseFirestore.instance.collection('portoes').doc(idPortao).get(const GetOptions(source: Source.server)).timeout(const Duration(milliseconds: 800));
      if (docAtual.exists && docAtual.data()!['ultima_abertura'] != null && DateTime.now().difference((docAtual.data()!['ultima_abertura'] as Timestamp).toDate()).inSeconds.abs() < tempoAbertura) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text("Aguarde! Portão já está em movimento.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
        return; 
      }
    } catch(_) {}
    FirebaseFirestore.instance.collection('portoes').doc(idPortao).update({'ultima_abertura': FieldValue.serverTimestamp()}).then((_) {}, onError: (_) {});
    GerenciadorDeTunel.registrarMovimentoRele(dataPortao['codigo']);
    try {
      final token = FirebaseAuth.instance.currentUser != null ? await FirebaseAuth.instance.currentUser!.getIdToken() : '';
      final response = await http.post(Uri.parse('https://us-central1-logichome-a9808.cloudfunctions.net/solicitarAberturaPortao'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({'data': {'id_dispositivo': dataPortao['id_box'], 'id_portao': idPortao, 'rele': dataPortao['codigo'], 'operador': widget.userData['nome']}}));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body)['result'] ?? jsonDecode(response.body)['data'];
        if (!mounted) return;
        if (result != null && result['sucesso'] == false && result['motivo'] == 'em_movimento') { ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), backgroundColor: Colors.orange.shade800, content: const Row(children: [Icon(Icons.warning, color: Colors.white), SizedBox(width: 10), Expanded(child: Text("Aguarde! Portão já está em movimento.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]))); return; }
        await registrarAuditoria(widget.userData['sindico_vinculado'], "Abertura Pelo Morador", "Interfonia/App", "Portão ${dataPortao['nome']} acionado por ${widget.userData['nome']}.");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Portão abrindo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
      } else throw Exception("Falha de conexão com a Placa.");
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Falha ao comunicar com o portão."))); }
  }

  Widget _abaInterfonia() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _regrasSindicoStream, 
      builder: (context, snapRegras) {
        if (!snapRegras.hasData) return const Center(child: CircularProgressIndicator());
        final idadeMorador = _calcularIdadeMorador();
        final idadeExigida = (snapRegras.data!.data() as Map<String, dynamic>)['idade_minima_portoes'] ?? 18;
        
        if (idadeMorador < idadeExigida) {
          return Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock, size: 100, color: Theme.of(context).colorScheme.error), const SizedBox(height: 20), Text("Acesso Restrito", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error)), const SizedBox(height: 10), Text("O acesso às câmeras e a abertura de portões exige idade mínima de $idadeExigida anos, conforme regra definida pela administração do condomínio.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))])));
        }
        
        return Column(children:[
          StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('cameras').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('visivel_morador', isEqualTo: true).snapshots(), builder: (context, snap) {
            if (snap.hasError || !snap.hasData) return const SizedBox.shrink();
            final meuBloco = (widget.userData['bloco'] ?? '').toString().toUpperCase().trim();
            final camerasPermitidas = snap.data!.docs.where((doc) {
              final nomeCamera = ((doc.data() as Map<String, dynamic>)['nome'] ?? '').toString().toUpperCase();
              if (nomeCamera.contains('-BLOCO') || nomeCamera.contains(' BLOCO')) {
                final partes = nomeCamera.split('BLOCO');
                if (partes.length > 1 && partes[1].replaceAll(RegExp(r'[^A-Z0-9]'), '').trim() != meuBloco) return false;
              }
              return true; 
            }).toList();
            if (camerasPermitidas.isEmpty) return const SizedBox.shrink(); 
            return Container(width: double.infinity, height: 300, color: Colors.black, child: PageView.builder(itemCount: camerasPermitidas.length, itemBuilder: (context, index) => PlayerNuvem(nomeCamera: (camerasPermitidas[index].data() as Map<String, dynamic>)['nome'] ?? 'Câmera', cameraId: camerasPermitidas[index].id, sindicoVinculado: widget.userData['sindico_vinculado'])));
          }),
          const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: Text("Abrir Portões Rápidos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))),
          Expanded(child: FutureBuilder<QuerySnapshot>(future: FirebaseFirestore.instance.collection('portoes').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('permite_morador', isEqualTo: true).get(const GetOptions(source: Source.serverAndCache)), builder: (context, snap) {
            if (snap.hasError) return const Center(child: Text("Erro ao carregar"));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhum portão liberado para uso via app."));
            HelperOffline.salvarPortoesNoCofre(snap.data!.docs.map((d) => (d.data() as Map<String, dynamic>)..['id_portao'] = d.id).toList());
            return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: snap.data!.docs.length, itemBuilder: (context, i) { final data = snap.data!.docs[i].data() as Map<String, dynamic>; return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.door_sliding, color: Colors.white)), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))), subtitle: Padding(padding: const EdgeInsets.only(top: 15, bottom: 5), child: SliderAbrirPortao(nomePortao: data['nome'], onSlid: () => _abrirPortaoMorador(data, snap.data!.docs[i].id), onBluetoothPressed: () => _abrirPortaoMorador(data, snap.data!.docs[i].id, usarBluetooth: true))))); });
          }))
        ]);
      }
    );
  }

  Widget _abaConvites() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children:[Center(child: Icon(Icons.insert_link, size: 80, color: colorScheme.secondary)), const SizedBox(height: 20), const Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text("Link VIP para Visitas", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)))), const SizedBox(height: 10), Text("Gere um link para sua visita preencher os dados pelo celular.", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16), textAlign: TextAlign.center), const SizedBox(height: 40), LogicNeonButton(fullWidth: true, corBase: colorScheme.secondary, corBrilho: colorScheme.secondary, onPressed: () async { final tokenLink = (Random.secure().nextInt(900000) + 100000).toString(); await FirebaseFirestore.instance.collection('convites_vip').add({'sindico_vinculado': widget.userData['sindico_vinculado'], 'bloco': widget.userData['bloco'], 'ap': widget.userData['ap'], 'morador': widget.userData['nome'], 'token': tokenLink, 'status': 'pendente', 'data_criacao': FieldValue.serverTimestamp()}); String host = "https://app-logichome.web.app"; if (kIsWeb) { try { if (!Uri.base.origin.contains("localhost")) host = Uri.base.origin; } catch (_) {} } // ignore: deprecated_member_use
        // ignore: deprecated_member_use
        Share.share('Você foi convidado para visitar ${widget.userData['nome']} no Bloco ${widget.userData['bloco']} AP ${widget.userData['ap']}.\n\nPreencha seus dados antecipadamente para liberar sua entrada na portaria acessando o link:\n\n$host/#/vip/$tokenLink'); if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link gerado! A janela de compartilhamento deve abrir em instantes."), backgroundColor: Colors.green)); }, child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.share, color: Colors.white, size: 18), SizedBox(width: 8), Text("GERAR LINK VIP", style: TextStyle(color: Colors.white))]))]));
  }

  Widget _abaEncomendas() {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<DocumentSnapshot>(stream: _regrasSindicoStream, builder: (context, snapRegras) {
      if (!snapRegras.hasData) return const Center(child: CircularProgressIndicator());
      final idadeMorador = _calcularIdadeMorador();
      final idadeExigida = (snapRegras.data!.data() as Map<String, dynamic>)['idade_minima_encomendas'] ?? 12;
      
      if (idadeMorador < idadeExigida) {
        return Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2, size: 100, color: colorScheme.error), const SizedBox(height: 20), Text("Acesso Restrito", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.error)), const SizedBox(height: 10), Text("A retirada de encomendas e pacotes exige idade mínima de $idadeExigida anos, conforme regra definida pela administração.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))])));
      }

      return StreamBuilder<QuerySnapshot>(stream: _minhasEncomendasStream, builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text("Erro ao carregar pacotes."));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final meuNomeOficial = widget.userData['nome'].toString().toUpperCase().trim(), meuEmail = widget.userData['email'] ?? '';
        final minhasEncomendas = snap.data!.docs.where((d) { final data = d.data() as Map<String, dynamic>, nomeNoPacote = (data['morador'] ?? '').toString().toUpperCase().trim(), ehPrivadoMeu = nomeNoPacote.contains(meuNomeOficial) || meuNomeOficial.contains(nomeNoPacote); return data['destinatario_indireto'] == true ? ((data['pins_por_morador'] ?? {}) as Map).containsKey(meuEmail) || ehPrivadoMeu : ehPrivadoMeu; }).toList();
        final aguardando = minhasEncomendas.where((d) => (d.data() as Map)['status'] == 'aguardando').toList(), emRetirada = minhasEncomendas.where((d) => (d.data() as Map)['status'] == 'em_retirada').toList();
        final entregues = minhasEncomendas.where((d) => (d.data() as Map)['status'] == 'entregue' || (d.data() as Map)['status'] == 'confirmado_morador').toList()..sort((a, b) => ((b.data() as Map)['data_registro'] ?? Timestamp.now()).compareTo((a.data() as Map)['data_registro'] ?? Timestamp.now()));
        Map<String, List<QueryDocumentSnapshot>> retiradasPorPin = {};
        for(final d in emRetirada) { final data = d.data() as Map<String, dynamic>; String pinDessePacote = data['codigo'] ?? ''; if (data['destinatario_indireto'] == true && data.containsKey('pins_por_morador') && data['pins_por_morador'][meuEmail] != null) pinDessePacote = data['pins_por_morador'][meuEmail]; retiradasPorPin.putIfAbsent(pinDessePacote, () => []).add(d); }
        
        return DefaultTabController(
          length: 2, 
          child: Column(children:[
            TabBar(labelColor: colorScheme.primary, unselectedLabelColor: colorScheme.onSurfaceVariant, tabs: const[Tab(text: "Na Portaria"), Tab(text: "Histórico")]), 
            Expanded(child: TabBarView(children:[
              ListView(padding: const EdgeInsets.all(16), children:[
                if (retiradasPorPin.isNotEmpty) ...retiradasPorPin.entries.map((entry) { 
                  final pin = entry.key, docsDoPin = entry.value, totalBipados = docsDoPin.fold(0, (somaAt, doc) => somaAt + ((doc.data() as Map)['codigos_bipados'] as List).length); 
                  return Card(color: colorScheme.primaryContainer, margin: const EdgeInsets.only(bottom: 20), shape: RoundedRectangleBorder(side: BorderSide(color: colorScheme.primary, width: 2), borderRadius: BorderRadius.circular(10)), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children:[Icon(Icons.handshake, color: colorScheme.primary), FittedBox(fit: BoxFit.scaleDown, child: Text("Validação de Entrega (PIN: $pin)", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer, fontSize: 16)))]), const Divider(height: 30), Text("O porteiro registrou a saída de $totalBipados pacote(s) para o seu apartamento.", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onPrimaryContainer)), const SizedBox(height: 10), Text("Por favor, confira se a quantidade física sobre o balcão corresponde exatamente a este número. Ao confirmar, esta entrega será finalizada e registrada em seu nome.", style: TextStyle(color: colorScheme.onPrimaryContainer.withValues(alpha:0.8), fontSize: 14)), const SizedBox(height: 25), StatefulBuilder(builder: (context, setStateSB) { return LogicNeonButton(fullWidth: true, corBase: Colors.green.shade700, corBrilho: Colors.greenAccent, onPressed: () async { try { final batch = FirebaseFirestore.instance.batch(); for(final d in docsDoPin) batch.update(d.reference, {'status': 'confirmado_morador', 'quem_retirou': widget.userData['nome']}); await batch.commit(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recebimento confirmado! O porteiro já pode finalizar."), backgroundColor: Colors.green)); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao confirmar: $e"), backgroundColor: colorScheme.error)); } }, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle, color: Colors.white, size: 18), const SizedBox(width: 8), Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: Text("CONFIRMAR $totalBipados PACOTES", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))))])); })]))); 
                }), 
                const Text("Aguardando sua retirada", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 10), 
                if (aguardando.isEmpty && emRetirada.isEmpty) Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Nenhuma encomenda no momento.", style: TextStyle(color: colorScheme.onSurfaceVariant)))), 
                ...aguardando.map((doc) { 
                  final data = doc.data() as Map<String, dynamic>, barras = data['codigos_barras'] ?? [], isIndireto = data['destinatario_indireto'] == true; String pinExibido = data['codigo']; if (isIndireto && data.containsKey('pins_por_morador') && data['pins_por_morador'][meuEmail] != null) pinExibido = data['pins_por_morador'][meuEmail]; 
                  return Card(elevation: 2, color: colorScheme.surface, margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(16.0), child: Wrap(spacing: 15, crossAxisAlignment: WrapCrossAlignment.center, children:[Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)), child: Icon(isIndireto ? Icons.family_restroom : Icons.inventory_2, color: colorScheme.primary, size: 40)), Column(crossAxisAlignment: CrossAxisAlignment.start, children:[FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("${barras.length} Pacote(s)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface))), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['morador'] ?? '', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12))), if (isIndireto) FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: const Text("Destinatário Não Cadastrado", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold))), const SizedBox(height: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.green.withValues(alpha:0.2), borderRadius: BorderRadius.circular(5)), child: Text("CÓDIGO (PIN): $pinExibido", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 1)))])]))); 
                })
              ]), 
              entregues.isEmpty ? Center(child: Text("Seu histórico está vazio.", style: TextStyle(color: colorScheme.onSurfaceVariant))) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: entregues.length, itemBuilder: (ctx, i) { 
                final data = entregues[i].data() as Map<String, dynamic>, codigosBarras = data['codigos_barras'] ?? [], codigosBipados = data['codigos_bipados'] ?? [], indireto = data['destinatario_indireto'] == true, dataEnt = data['data_registro'] != null ? DateFormat('dd/MM/yyyy').format((data['data_registro'] as Timestamp).toDate()) : "N/D", horaEnt = data['data_registro'] != null ? DateFormat('HH:mm').format((data['data_registro'] as Timestamp).toDate()) : "N/D", dataRet = data['data_entrega'] != null ? DateFormat('dd/MM/yyyy').format((data['data_entrega'] as Timestamp).toDate()) : "N/D", horaRet = data['data_entrega'] != null ? DateFormat('HH:mm').format((data['data_entrega'] as Timestamp).toDate()) : "N/D"; 
                return Card(elevation: 2, margin: const EdgeInsets.only(bottom: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Row(children:[const Icon(Icons.check_circle, color: Colors.green, size: 30), const SizedBox(width: 10), Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Destinatário: ${data['morador']?.toString().toUpperCase() ?? 'N/D'}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.onSurface))))]), const Divider(height: 25, thickness: 1), RichText(text: TextSpan(style: TextStyle(color: colorScheme.onSurface, fontSize: 13, height: 1.5), children:[const TextSpan(text: "Dest: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${data['morador']?.toString().toUpperCase() ?? 'N/D'} | "), const TextSpan(text: "Data de ent: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "$dataEnt | "), const TextSpan(text: "Hora da entrega: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "$horaEnt | "), const TextSpan(text: "Porteiro: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${data['operador_recebimento'] ?? 'N/D'} | "), const TextSpan(text: "Entregador: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${data['empresa_entregadora'] ?? 'N/D'} | "), const TextSpan(text: "Quantidade: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${codigosBarras.length}")])), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: codigosBarras.isEmpty ? <Widget>[Text("Nenhum código registrado", style: TextStyle(fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant))] : codigosBarras.map<Widget>((c) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(5), border: Border.all(color: colorScheme.primary)), child: Row(mainAxisSize: MainAxisSize.min, children:[Icon(Icons.qr_code, size: 12, color: colorScheme.primary), const SizedBox(width: 5), Text(c.toString(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer))]))).toList()), const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(thickness: 1)), RichText(text: TextSpan(style: TextStyle(color: colorScheme.onSurface, fontSize: 13, height: 1.5), children:[const TextSpan(text: "Data da retirada: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "$dataRet | "), const TextSpan(text: "Hora da retirada: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "$horaRet | "), const TextSpan(text: "Porteiro: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${data['operador_entrega'] ?? 'N/D'} | "), const TextSpan(text: "Morador que assinou: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${data['quem_retirou'] ?? 'N/D'} | "), const TextSpan(text: "Volumes entregues: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${codigosBipados.length}"), if (indireto) ...[const TextSpan(text: " | Moradores não cadastrados: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)), TextSpan(text: "${data['morador']}", style: const TextStyle(color: Colors.orange))]])), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: codigosBipados.isEmpty ? <Widget>[Text("Nenhum código bipado na retirada", style: TextStyle(fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant))] : codigosBipados.map<Widget>((c) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: Colors.green.withValues(alpha:0.1), borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.green)), child: Row(mainAxisSize: MainAxisSize.min, children:[const Icon(Icons.qr_code, size: 12, color: Colors.green), const SizedBox(width: 5), Text(c.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green))]))).toList())]))); 
              })
            ]))
          ])
        );
      });
    });
  }

  Widget _abaAvisos() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_carregandoAvisos) return const Center(child: CircularProgressIndicator());
    if (_avisosLocais.isEmpty) return ListView(padding: const EdgeInsets.all(16), children:[const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Mural de Recados", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Avisos importantes enviados pela administração.", style: TextStyle(color: colorScheme.onSurfaceVariant))), const SizedBox(height: 20), Text("Nenhum aviso da administração no momento.", style: TextStyle(color: colorScheme.onSurfaceVariant))]);
    return ListView(padding: const EdgeInsets.all(16), children:[
      const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Mural de Recados", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Avisos importantes enviados pela administração.", style: TextStyle(color: colorScheme.onSurfaceVariant))), const SizedBox(height: 20),
      ..._avisosLocais.map((data) {
        final t = data['data'] as Timestamp?, dataStr = t != null ? DateFormat('dd/MM HH:mm').format(t.toDate()) : "Agora", isPrivado = data['para'] != 'todos', corFundo = isPrivado ? colorScheme.secondaryContainer : colorScheme.primaryContainer, corBorda = isPrivado ? colorScheme.secondary : colorScheme.primary, corTag = isPrivado ? colorScheme.onSecondaryContainer : colorScheme.onPrimaryContainer;
        return Card(color: corFundo, margin: const EdgeInsets.only(bottom: 12), elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: corBorda.withValues(alpha:0.5))), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[FittedBox(fit: BoxFit.scaleDown, child: Text(isPrivado ? "🔒 MENSAGEM DIRETA" : "📍 AVISO GERAL", style: TextStyle(color: corTag, fontWeight: FontWeight.bold, fontSize: 12))), FittedBox(fit: BoxFit.scaleDown, child: Text(dataStr, style: TextStyle(color: corTag.withValues(alpha:0.8), fontSize: 12)))]), const SizedBox(height: 10), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['titulo'] ?? 'Sem Título', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: corTag))), const SizedBox(height: 5), Text(data['mensagem'] ?? '', style: TextStyle(color: corTag.withValues(alpha:0.9)))])));
      }),
      Padding(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20), child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(15)), icon: const Icon(Icons.history), label: const Text("CARREGAR MAIS ANTIGOS"), onPressed: () {
        setState(() => _carregandoAvisos = true);
        _limiteNotificacoesMorador += 20;
        _initStreams();
      }))
    ]);
  }

  Future<void> _gerarPdfExtrato(List<QueryDocumentSnapshot> faturas, List<QueryDocumentSnapshot> extras) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (context) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Header(level: 0, child: pw.Text("Extrato Financeiro Condominial", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
      pw.Text("Morador: ${widget.userData['nome']} (Bloco ${widget.userData['bloco']} / AP ${widget.userData['ap']})"),
      pw.Text("Data de Emissao: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}"), pw.SizedBox(height: 20),
      pw.Text("Historico de Faturas Base", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), pw.Divider(),
      ...faturas.map((f) { final d = f.data() as Map<String, dynamic>, status = (d['status'] == 'RECEIVED' || d['status'] == 'CONFIRMED') ? 'PAGO' : 'PENDENTE/VENCIDO'; return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Venc: ${d['vencimento']} - Status: $status"), pw.Text("R\$ ${d['valor']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))])); }),
      pw.SizedBox(height: 30), pw.Text("Detalhamento de Multas e Taxas de Area Comum", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), pw.Divider(),
      ...extras.map((e) { final d = e.data() as Map<String, dynamic>, tipo = d['tipo'].toString().toUpperCase(), isEstorno = (d['valor'] as num) < 0; return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("[$tipo] ${d['titulo']}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("R\$ ${d['valor']}", style: pw.TextStyle(color: isEstorno ? PdfColors.blue : PdfColors.red))]), pw.Text("Detalhes: ${d['descricao']}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))])); }),
      pw.Spacer(), pw.Divider(), pw.Center(child: pw.Text("Gerado pelo Sistema Logic Home", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)))
    ])));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Extrato_Condominio');
  }

  Widget _abaFinanceiroMorador() {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('faturas_moradores').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('email_morador', isEqualTo: widget.userData['email']).snapshots(), builder: (context, snapFaturas) {
      return StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('cobrancas_extras').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('email_morador', isEqualTo: widget.userData['email']).snapshots(), builder: (context, snapExtras) {
        if (!snapFaturas.hasData || !snapExtras.hasData) return const Center(child: CircularProgressIndicator());
        final faturas = snapFaturas.data!.docs, extras = snapExtras.data!.docs;
        return Column(children: [
          Container(width: double.infinity, padding: const EdgeInsets.all(12), color: Colors.blue.withValues(alpha:0.1), child: Row(children: [const Icon(Icons.info_outline, color: Colors.blue, size: 30), const SizedBox(width: 10), Expanded(child: Text("As faturas oficiais e de responsabilidade legal são enviadas exclusivamente via E-mail para o Proprietário cadastrado na base da Administradora. Este painel é apenas um espelho para facilitar visualização e pagamento.", style: TextStyle(color: Colors.blue.shade800, fontSize: 11)))])),
          Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Meu Financeiro", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: colorScheme.onSecondary), icon: const Icon(Icons.picture_as_pdf, size: 18), label: const Text("GERAR EXTRATO"), onPressed: () => _gerarPdfExtrato(faturas, extras))])),
          Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
            const Text("Faturas do Condomínio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 10),
            if (faturas.isEmpty) const Text("Nenhum boleto encontrado.", style: TextStyle(color: Colors.grey)),
            ...faturas.map((f) { final data = f.data() as Map<String, dynamic>, pago = data['status'] == 'RECEIVED' || data['status'] == 'CONFIRMED'; bool vencido = false; try { final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day); final vencDt = DateTime.parse(data['vencimento'].toString()); if (!pago && vencDt.isBefore(hoje)) vencido = true; } catch(_) {} final corStatus = pago ? Colors.green : (vencido ? Colors.red : Colors.orange); return Card(shape: RoundedRectangleBorder(side: BorderSide(color: corStatus, width: 2), borderRadius: BorderRadius.circular(10)), child: ListTile(leading: Icon(pago ? Icons.check_circle : (vencido ? Icons.error : Icons.warning), color: corStatus, size: 30), title: Text("Vencimento: ${data['vencimento']}", style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Valor Base: R\$ ${data['valor']}"), trailing: !pago && data['url_fatura'] != null ? Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [if (vencido) const Text("ATRASADO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: vencido ? Colors.red : null, foregroundColor: vencido ? Colors.white : null, visualDensity: VisualDensity.compact), onPressed: () => launchUrl(Uri.parse(data['url_fatura']), mode: LaunchMode.externalApplication), child: const Text("PAGAR"))]) : Text("PAGO", style: TextStyle(color: corStatus, fontWeight: FontWeight.bold)))); }),
            const Divider(height: 40), const Text("Detalhamento (Multas e Reservas Extras)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Text("Estes valores são somados à sua fatura base do mês.", style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 10),
            if (extras.isEmpty) const Text("Você não possui cobranças extras.", style: TextStyle(color: Colors.green)),
            ...extras.map((e) { final data = e.data() as Map<String, dynamic>, isMulta = data['tipo'] == 'multa', isEstorno = (data['valor'] as num) < 0; return Card(child: ListTile(leading: Icon(isMulta ? Icons.gavel : Icons.deck, color: isMulta ? Colors.red : Colors.orange), title: Text("${data['titulo']} - R\$ ${data['valor']}", style: TextStyle(fontWeight: FontWeight.bold, color: isEstorno ? Colors.blue : null)), subtitle: Text(data['descricao']), trailing: isMulta && data['foto_prova_url'] != null && data['foto_prova_url'].toString().isNotEmpty ? IconButton(icon: const Icon(Icons.image, color: Colors.blue), onPressed: () => launchUrl(Uri.parse(data['foto_prova_url']))) : null)); })
          ]))
        ]);
      });
    });
  }
}

// [FIM DO BLOCO - DIGITE "CONTINUE" PARA GERAR A PRÓXIMA PARTE]
// ============================================================================
// PARTE 4 - ADMINISTRAÇÃO MASTER (SUPER USUÁRIO)
// ============================================================================

class TelaSaudeMaster extends StatefulWidget {
  const TelaSaudeMaster({super.key});
  @override
  State<TelaSaudeMaster> createState() => _TelaSaudeMasterState();
}

class _TelaSaudeMasterState extends State<TelaSaudeMaster> {
  final double custoOcr = 0.008, custoFoto = 0.005, custoPush = 0.001, custoBaseLeituras = 2.00;
  DateTime _mesFiltro = DateTime.now();
  final Map<String, List<Map<String, dynamic>>> _telemetriaCachePorMes = {};
  bool _carregando = false;

  @override
  void initState() { super.initState(); _carregarTelemetriaDoMes(_mesFiltro); }

  Future<void> _carregarTelemetriaDoMes(DateTime mes) async {
    final chaveMes = "${mes.month}_${mes.year}", cacheKey = 'telemetria_master_$chaveMes';
    final prefs = await SharedPreferences.getInstance();
    
    final hdDados = prefs.getString(cacheKey) ?? '';
    if (hdDados.isNotEmpty) {
      _telemetriaCachePorMes[chaveMes] = List<Map<String, dynamic>>.from(jsonDecode(hdDados));
      if (mounted) setState(() {});
    } else {
      if (mounted) setState(() => _carregando = true);
    }

    try {
      final snap = await FirebaseFirestore.instance.collection('telemetria_saas').where('mes_ano', isEqualTo: chaveMes).get(); 
      final dadosDoMes = snap.docs.map((doc) => doc.data()..['id'] = doc.id).toList();
      _telemetriaCachePorMes[chaveMes] = dadosDoMes;
      await prefs.setString(cacheKey, jsonEncode(dadosDoMes));
      if (mounted) setState(() => _carregando = false);
    } catch (e) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme, chaveMes = "${_mesFiltro.month}_${_mesFiltro.year}", mesAnoFormat = DateFormat('MM/yyyy').format(_mesFiltro);
    final docs = _telemetriaCachePorMes[chaveMes] ?? [];

    double totalOcr = 0, totalFotos = 0, totalPush = 0, custoTotalCloud = 0;
    final rankingCondominios = <Map<String, dynamic>>[];

    for (var data in docs) {
      final ocr = (data['uso_ocr_vision'] ?? 0).toDouble(), fotos = (data['uso_fotos_storage'] ?? 0).toDouble(), push = (data['uso_push_notifications'] ?? 0).toDouble();
      final custoDesteCondo = (ocr * custoOcr) + (fotos * custoFoto) + (push * custoPush) + custoBaseLeituras;
      totalOcr += (ocr * custoOcr); totalFotos += (fotos * custoFoto); totalPush += (push * custoPush); custoTotalCloud += custoDesteCondo;
      rankingCondominios.add({'email': data['sindico_vinculado'], 'custo': custoDesteCondo, 'acoes': (ocr + fotos + push).toInt()});
    }
    rankingCondominios.sort((a, b) => b['custo'].compareTo(a['custo']));

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 800;
      final graficoPizza = Card(
        elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(padding: const EdgeInsets.all(20.0), child: _carregando ? const Center(child: CircularProgressIndicator()) : Column(children: [const Text("Para onde seu dinheiro vai?", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Expanded(child: docs.isEmpty ? const Center(child: Text("Sem dados suficientes", style: TextStyle(color: Colors.grey))) : PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: isMobile ? 50 : 40, sections: [PieChartSectionData(color: Colors.blue, value: totalOcr, title: "IA (OCR)\nR\$ ${totalOcr.toStringAsFixed(2)}", radius: isMobile ? 60 : 50, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)), PieChartSectionData(color: Colors.purple, value: totalFotos, title: "Fotos\nR\$ ${totalFotos.toStringAsFixed(2)}", radius: isMobile ? 60 : 50, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)), PieChartSectionData(color: Colors.orange, value: totalPush, title: "Push\nR\$ ${totalPush.toStringAsFixed(2)}", radius: isMobile ? 60 : 50, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)), PieChartSectionData(color: Colors.grey, value: (docs.length * custoBaseLeituras), title: "Banco\nR\$ ${(docs.length * custoBaseLeituras).toStringAsFixed(2)}", radius: isMobile ? 60 : 50, titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))])))]))
      );

      final listaRanking = Card(
        elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(padding: const EdgeInsets.all(16.0), child: _carregando ? const Center(child: CircularProgressIndicator()) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Condomínios Mais Custosos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)), const Divider(), Expanded(child: rankingCondominios.isEmpty ? const Center(child: Text("Nenhuma operação registrada no mês.", style: TextStyle(color: Colors.grey))) : ListView.builder(itemCount: rankingCondominios.length, itemBuilder: (ctx, i) { final condo = rankingCondominios[i]; return ListTile(leading: CircleAvatar(backgroundColor: colorScheme.error.withValues(alpha:0.2), child: Text("#${i+1}", style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold))), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(condo['email'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))), subtitle: Text("${condo['acoes']} operações em nuvem", style: const TextStyle(fontSize: 11)), trailing: Text("R\$ ${condo['custo'].toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.error, fontSize: 14))); }))]))
      );

      return Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Monitoramento de Custos (Cloud)", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text("Auditoria Financeira do Sistema SaaS", style: TextStyle(color: colorScheme.onSurfaceVariant))])), Container(padding: const EdgeInsets.symmetric(horizontal: 5), decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.arrow_back_ios, size: 16), onPressed: () { setState(() => _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month - 1, 1)); _carregarTelemetriaDoMes(_mesFiltro); }), Text(mesAnoFormat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16), onPressed: () { setState(() => _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month + 1, 1)); _carregarTelemetriaDoMes(_mesFiltro); })]))]), const SizedBox(height: 15),
          Container(width: isMobile ? double.infinity : 400, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: colorScheme.errorContainer, borderRadius: BorderRadius.circular(10), border: Border.all(color: colorScheme.error)), child: Row(children: [Icon(Icons.cloud_upload, size: isMobile ? 35 : 50, color: colorScheme.error), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text("Custo Cloud Estimado (Mês)", style: TextStyle(color: colorScheme.onErrorContainer, fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 14)), const SizedBox(height: 5), FittedBox(fit: BoxFit.scaleDown, child: Text("R\$ ${custoTotalCloud.toStringAsFixed(2)}", style: TextStyle(color: colorScheme.error, fontSize: 32, fontWeight: FontWeight.bold)))])),])), const SizedBox(height: 20),
          Expanded(child: isMobile ? SingleChildScrollView(child: Column(children: [SizedBox(height: 350, child: graficoPizza), const SizedBox(height: 15), SizedBox(height: 400, child: listaRanking)])) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 1, child: graficoPizza), const SizedBox(width: 20), Expanded(flex: 1, child: listaRanking)]))
        ]),
      );
    });
  }
}

class PainelDev extends StatefulWidget {
  const PainelDev({super.key});
  @override
  State<PainelDev> createState() => _PainelDevState();
}

class _PainelDevState extends State<PainelDev> {
  int _abaIndex = 0;
  late Stream<QuerySnapshot> _sindicosStream, _planosStream;
  List<Map<String, dynamic>> _auditoriaTransfCache = [];
  bool _carregandoAuditoriaTransf = true, _buscandoNuvemAuditoriaTransf = false, _fimDaListaAuditoriaTransf = false;
  final ScrollController _scrollControllerAuditoriaTransf = ScrollController();
  StreamSubscription<QuerySnapshot>? _novasAuditoriasTransfSub;

  void _modalEditarMenusUsuario(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final menus = Map<String, dynamic>.from(data['menus_personalizados'] ?? {});
    final opcoes = const {'avisos': 'Mural de Avisos/Recados', 'encomendas': 'Recepção de Encomendas', 'estoque': 'Inventário e Estoque', 'visitantes': 'Controle de Visitantes', 'facial': 'Biometria Facial', 'cameras': 'Câmeras', 'portoes': 'Portões e Relés', 'reservas': 'Reservas de Áreas', 'gestao': 'Gestão (Moradores/Permissões)', 'ronda_gestao': 'Gestão de Rondas (Síndico)', 'ronda_virtual': 'Ronda Virtual (Porteiro)', 'financeiro': 'Financeiro / Faturas (Administradora)', 'despesas': 'Lançamento de Despesas (Síndico Local)', 'anotacoes': 'Anotações da Portaria', 'sobre': 'Sobre o Sistema'};

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) => AlertDialog(
      title: Text("Personalizar Menus: ${data['nome']}", style: const TextStyle(fontSize: 18)),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Desmarque os itens que você deseja ESCONDER para este usuário. (Se a licença/plano dele não cobrir, continuará oculto).", style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 10), ...opcoes.keys.map((key) => SwitchListTile(dense: true, title: Text(opcoes[key]!), value: menus[key] ?? true, activeThumbColor: Colors.blue, onChanged: (v) => setStateSB(() => menus[key] = v)))]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), onPressed: () async { await doc.reference.update({'menus_personalizados': menus}); if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menus atualizados com sucesso!"), backgroundColor: Colors.green)); } }, child: const Text("SALVAR"))],
    )));
  }

  @override
  void initState() {
    super.initState();
    _sindicosStream = FirebaseFirestore.instance.collection('usuarios').where('perfil', isEqualTo: 'sindico').snapshots();
    _planosStream = FirebaseFirestore.instance.collection('planos').snapshots();
    _scrollControllerAuditoriaTransf.addListener(_aoRolarTelaAuditoriaTransf);
    _carregarAuditoriaTransfDeltaSync();
  }

  @override
  void dispose() { _scrollControllerAuditoriaTransf.dispose(); _novasAuditoriasTransfSub?.cancel(); super.dispose(); }

  void _aoRolarTelaAuditoriaTransf() {
    if (_scrollControllerAuditoriaTransf.position.pixels >= _scrollControllerAuditoriaTransf.position.maxScrollExtent - 200) {
      if (!_buscandoNuvemAuditoriaTransf && !_fimDaListaAuditoriaTransf) _buscarMaisAntigosNaNuvemAuditoriaTransf();
    }
  }

  Future<void> _salvarCacheAuditoriaTransf(List<Map<String, dynamic>> lista) async {
    try {
      final jsonStr = jsonEncode(lista.map((item) => item.map((key, value) => MapEntry(key, value is Timestamp ? value.toDate().toIso8601String() : value))).toList());
      if (kIsWeb) await (await SharedPreferences.getInstance()).setString('auditoria_transf_master', jsonStr);
      else await File('${(await getApplicationDocumentsDirectory()).path}/auditoria_transf_master.json').writeAsString(jsonStr);
    } catch (_) {}
  }

  Future<void> _carregarAuditoriaTransfDeltaSync() async {
    try {
      String jsonString = "";
      if (kIsWeb) jsonString = (await SharedPreferences.getInstance()).getString('auditoria_transf_master') ?? "";
      else { final file = File('${(await getApplicationDocumentsDirectory()).path}/auditoria_transf_master.json'); if (await file.exists()) jsonString = await file.readAsString(); }

      if (jsonString.isNotEmpty) {
        _auditoriaTransfCache = (jsonDecode(jsonString) as List).map((item) {
          final mapa = Map<String, dynamic>.from(item);
          if (mapa['data_solicitacao'] != null && mapa['data_solicitacao'] is String) mapa['data_solicitacao'] = Timestamp.fromDate(DateTime.parse(mapa['data_solicitacao']));
          return mapa;
        }).toList();
      }
      if (mounted) setState(() => _carregandoAuditoriaTransf = false);

      Timestamp? ultimaData;
      if (_auditoriaTransfCache.isNotEmpty) {
        _auditoriaTransfCache.sort((a, b) => (b['data_solicitacao'] as Timestamp).compareTo(a['data_solicitacao'] as Timestamp));
        ultimaData = _auditoriaTransfCache.first['data_solicitacao'] as Timestamp;
      }

      if (ultimaData == null) {
        if (mounted) setState(() => _buscandoNuvemAuditoriaTransf = true);
        final snapInicial = await FirebaseFirestore.instance.collection('transferencias_gestao').orderBy('data_solicitacao', descending: true).limit(30).get();
        for (var doc in snapInicial.docs) _auditoriaTransfCache.add(doc.data()..['id'] = doc.id);
        if (mounted) setState(() => _buscandoNuvemAuditoriaTransf = false);
        await _salvarCacheAuditoriaTransf(_auditoriaTransfCache);
      } else {
        final snapNovos = await FirebaseFirestore.instance.collection('transferencias_gestao').where('data_solicitacao', isGreaterThan: ultimaData).get();
        if (snapNovos.docs.isNotEmpty) {
          for (var doc in snapNovos.docs) _auditoriaTransfCache.insert(0, doc.data()..['id'] = doc.id);
          _auditoriaTransfCache.sort((a, b) => (b['data_solicitacao'] as Timestamp).compareTo(a['data_solicitacao'] as Timestamp));
          if (mounted) setState(() {});
          await _salvarCacheAuditoriaTransf(_auditoriaTransfCache);
        }
      }

      final inicioHoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      _novasAuditoriasTransfSub?.cancel();
      _novasAuditoriasTransfSub = FirebaseFirestore.instance.collection('transferencias_gestao').where('data_solicitacao', isGreaterThan: Timestamp.fromDate(inicioHoje)).snapshots().listen((snap) {
        bool alterou = false;
        for (var change in snap.docChanges) {
          final data = change.doc.data()!..['id'] = change.doc.id;
          final idx = _auditoriaTransfCache.indexWhere((v) => v['id'] == change.doc.id);
          if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
            if (idx != -1) _auditoriaTransfCache[idx] = data; else _auditoriaTransfCache.insert(0, data);
            alterou = true;
          }
        }
        if (alterou) {
          _auditoriaTransfCache.sort((a, b) => (b['data_solicitacao'] as Timestamp).compareTo(a['data_solicitacao'] as Timestamp));
          if (mounted) setState(() {});
          _salvarCacheAuditoriaTransf(_auditoriaTransfCache);
        }
      });
    } catch (e) { if (mounted) setState(() => _carregandoAuditoriaTransf = false); }
  }

  Future<void> _buscarMaisAntigosNaNuvemAuditoriaTransf() async {
    setState(() => _buscandoNuvemAuditoriaTransf = true);
    try {
      final dataMaisVelha = _auditoriaTransfCache.isNotEmpty ? _auditoriaTransfCache.last['data_solicitacao'] as Timestamp? : null;
      if (dataMaisVelha != null) {
        final snap = await FirebaseFirestore.instance.collection('transferencias_gestao').where('data_solicitacao', isLessThan: dataMaisVelha).orderBy('data_solicitacao', descending: true).limit(20).get();
        if (snap.docs.isNotEmpty) {
          for (var doc in snap.docs) { final data = doc.data()..['id'] = doc.id; if (!_auditoriaTransfCache.any((m) => m['id'] == doc.id)) _auditoriaTransfCache.add(data); }
          if (mounted) setState(() {});
          _salvarCacheAuditoriaTransf(_auditoriaTransfCache);
        } else { _fimDaListaAuditoriaTransf = true; }
      }
    } catch (_) {}
    if (mounted) setState(() => _buscandoNuvemAuditoriaTransf = false);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final navRail = NavigationRail(extended: !isMobile, selectedIndex: _abaIndex, onDestinationSelected: (i) { setState(() => _abaIndex = i); if (isMobile) Navigator.pop(context); }, destinations: const [NavigationRailDestination(icon: Icon(Icons.business), label: Text('Condomínios')), NavigationRailDestination(icon: Icon(Icons.corporate_fare), label: Text('Administradoras')), NavigationRailDestination(icon: Icon(Icons.analytics), label: Text('Custos SaaS')), NavigationRailDestination(icon: Icon(Icons.view_list), label: Text('Planos de Acesso')), NavigationRailDestination(icon: Icon(Icons.admin_panel_settings), label: Text('Equipe Master')), NavigationRailDestination(icon: Icon(Icons.swap_horizontal_circle), label: Text('Auditoria Transf.')), NavigationRailDestination(icon: Icon(Icons.account_balance), label: Text('Faturamento Asaas'))]);

    return Scaffold(
      appBar: AppBar(title: FittedBox(fit: BoxFit.scaleDown, child: Text("SaaS Master | Op: $operadorLogado")), actions:[const BotaoTrocarTema(), IconButton(icon: const Icon(Icons.logout), onPressed: () async { await FirebaseAuth.instance.signOut(); if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TelaLogin())); })]),
      drawer: isMobile ? Drawer(child: SafeArea(child: navRail)) : null,
      body: Row(children:[if (!isMobile) navRail, if (!isMobile) const VerticalDivider(width: 1), Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), switchInCurve: Curves.easeIn, switchOutCurve: Curves.easeOut, transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child), child: Container(key: ValueKey<int>(_abaIndex), child: _buildBodyMaster())))]),
    );
  }

  Widget _buildBodyMaster() {
    switch (_abaIndex) {
      case 0: return _buildAbaCondos();
      case 1: return _abaAdministradoras();
      case 2: return const TelaSaudeMaster();
      case 3: return _abaPlanos();
      case 4: return _abaEquipeMaster();
      case 5: return _abaAuditoriaTransferencias();
      default: return const PainelFaturamentoSaaS();
    }
  }

  Widget _abaAdministradoras() {
    void modalNovaAdministradora() {
      String nomeLegal = "", email = "", senha = "", cpfCnpj = "", nascimento = "", tipoEmpresa = "MEI", telefone = "", cep = "", endereco = "", numero = "", complemento = "", bairro = "", faturamento = "";
      bool criando = false, ocultarSenha = true;

      showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Row(children:[Icon(Icons.domain_add, color: colorScheme.primary), const SizedBox(width: 10), const Text("Nova Administradora")]),
          content: SizedBox(width: 550, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children:[
            const Text("Preencha todos os dados exigidos pelo Banco Central (Asaas) para garantir a credibilidade e rápida liberação da conta financeira da agência.", style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 15),
            const Align(alignment: Alignment.centerLeft, child: Text("Dados de Acesso (Login):", style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(height: 8),
            Row(children: [Expanded(child: TextField(onChanged: (v) => email = v.toLowerCase().trim(), decoration: const InputDecoration(labelText: "E-mail de Acesso *", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(onChanged: (v) => senha = v, obscureText: ocultarSenha, decoration: InputDecoration(labelText: "Senha Inicial *", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(ocultarSenha ? Icons.visibility_off : Icons.visibility), onPressed: () => setStateSB(() => ocultarSenha = !ocultarSenha))))) ]), const SizedBox(height: 15),
            const Align(alignment: Alignment.centerLeft, child: Text("Dados Cadastrais (Financeiro):", style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(height: 8),
            TextField(onChanged: (v) => nomeLegal = v, decoration: const InputDecoration(labelText: "Nome Legal (Empresa ou Pessoa) *", border: OutlineInputBorder())), const SizedBox(height: 10),
            Row(children: [Expanded(flex: 2, child: DropdownButtonFormField<String>(isExpanded: true, initialValue: tipoEmpresa, decoration: const InputDecoration(labelText: "Tipo *", border: OutlineInputBorder()), items: const [DropdownMenuItem(value: "INDIVIDUAL", child: Text("Pessoa Física")), DropdownMenuItem(value: "MEI", child: Text("Empresa MEI")), DropdownMenuItem(value: "LIMITED", child: Text("Empresa LTDA")), DropdownMenuItem(value: "ASSOCIATION", child: Text("Associação"))], onChanged: (v) => setStateSB(() => tipoEmpresa = v!))), const SizedBox(width: 10), Expanded(flex: 3, child: TextField(onChanged: (v) => cpfCnpj = v, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "CPF ou CNPJ *", border: OutlineInputBorder())))]), const SizedBox(height: 10),
            Row(children: [Expanded(child: TextField(onChanged: (v) => nascimento = v, keyboardType: TextInputType.number, inputFormatters: [DataFormatter()], decoration: const InputDecoration(labelText: "Fundação/Nascimento *", hintText: "DD/MM/AAAA", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(onChanged: (v) => faturamento = v.replaceAll(',', '.'), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Faturamento (R\$) *", border: OutlineInputBorder())))]), const SizedBox(height: 10),
            Row(children: [Expanded(flex: 1, child: TextField(onChanged: (v) => cep = v, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "CEP *", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(flex: 2, child: TextField(onChanged: (v) => telefone = v, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefone/Celular *", border: OutlineInputBorder())))]), const SizedBox(height: 10),
            Row(children: [Expanded(flex: 2, child: TextField(onChanged: (v) => endereco = v, decoration: const InputDecoration(labelText: "Endereço (Rua) *", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(flex: 1, child: TextField(onChanged: (v) => numero = v, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Nº *", border: OutlineInputBorder())))]), const SizedBox(height: 10),
            Row(children: [Expanded(child: TextField(onChanged: (v) => complemento = v, decoration: const InputDecoration(labelText: "Complemento", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(onChanged: (v) => bairro = v, decoration: const InputDecoration(labelText: "Bairro *", border: OutlineInputBorder())))]),
          ]))),
          actions:[
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
            criando ? const CircularProgressIndicator() : ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async {
              if (email.isEmpty || senha.isEmpty || nomeLegal.isEmpty || cpfCnpj.isEmpty || nascimento.isEmpty || telefone.isEmpty || cep.isEmpty || endereco.isEmpty || numero.isEmpty || bairro.isEmpty || faturamento.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos obrigatórios (*)."))); return; }
              setStateSB(() => criando = true);
              try {
                final resultado = await FirebaseService.criarUsuarioSaaS(email: email, senha: senha, nome: nomeLegal, perfil: 'administradora');
                if (!mounted) return;
                if (resultado['sucesso'] == true) {
                  await FirebaseFirestore.instance.collection('usuarios').doc(email).update({'condominios_gerenciados': [], 'cpfCnpj': cpfCnpj, 'nascimento': nascimento, 'tipoEmpresa': tipoEmpresa, 'telefone': telefone, 'cep': cep, 'endereco': endereco, 'numero': numero, 'complemento': complemento, 'bairro': bairro, 'faturamento': faturamento, 'dados_bancarios_preenchidos': true});
                  Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Administradora criada com sucesso!"), backgroundColor: Colors.green));
                } else { setStateSB(() => criando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: ${resultado['erro']}"), backgroundColor: colorScheme.error)); }
              } catch (e) { setStateSB(() => criando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro inesperado: $e"), backgroundColor: colorScheme.error)); }
            }, child: const Text("CRIAR CONTA"))
          ],
        );
      }));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: modalNovaAdministradora, icon: const Icon(Icons.domain_add), label: const Text("Nova Administradora")),
      body: Column(children:[
        const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text("Gestão de Administradoras (Agências)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('usuarios').where('perfil', isEqualTo: 'administradora').snapshots(), builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text("Erro ao carregar administradoras."));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhuma administradora cadastrada no SaaS."));
          final colorScheme = Theme.of(context).colorScheme;
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, itemBuilder: (context, index) {
            final doc = snap.data!.docs[index], data = doc.data() as Map<String, dynamic>, gerenciados = data['condominios_gerenciados'] ?? [];
            return Card(child: ListTile(
              leading: CircleAvatar(backgroundColor: colorScheme.secondaryContainer, child: Icon(Icons.corporate_fare, color: colorScheme.onSecondaryContainer)),
              title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold))),
              subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("${data['email']} - Gerencia ${gerenciados.length} condomínio(s)")),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: Icon(Icons.view_sidebar, color: colorScheme.primary), tooltip: "Editar Menus", onPressed: () => _modalEditarMenusUsuario(doc)),
                IconButton(icon: Icon(Icons.delete, color: colorScheme.error), tooltip: "Excluir Administradora", onPressed: () { showDialog(context: context, builder: (c) => AlertDialog(title: Text("Excluir Administradora", style: TextStyle(color: colorScheme.error)), content: const Text("Isso apagará o acesso da administradora. Os condomínios NÃO serão apagados, apenas perderão o vínculo. Confirma?"), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError), onPressed: () async { if (gerenciados.isNotEmpty) { final batch = FirebaseFirestore.instance.batch(); for(String emailCondo in gerenciados) batch.update(FirebaseFirestore.instance.collection('usuarios').doc(emailCondo), {'administradora_vinculada': FieldValue.delete()}); await batch.commit(); } await doc.reference.delete(); if (mounted) Navigator.pop(c); }, child: const Text("EXCLUIR"))])); })
              ])
            ));
          });
        }))
      ]),
    );
  }

  void _modalTransferirGestao(DocumentSnapshot doc) {
    final dataAtual = doc.data() as Map<String, dynamic>;
    String novoEmail = "", novoNome = "";
    bool enviando = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Row(children:[Icon(Icons.swap_horiz, color: colorScheme.primary), const SizedBox(width: 10), const Text("Transferir Titularidade")]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[
          FittedBox(fit: BoxFit.scaleDown, child: Text("Condomínio: ${dataAtual['condominio']}", style: const TextStyle(fontWeight: FontWeight.bold))),
          FittedBox(fit: BoxFit.scaleDown, child: Text("Síndico Atual: ${dataAtual['nome']} (${doc.id})", style: const TextStyle(color: Colors.grey))), const Divider(),
          const Text("ATENÇÃO: Ao preencher os dados abaixo, um protocolo será gerado. A transferência real só ocorrerá quando o SÍNDICO ATUAL aceitar a solicitação no aplicativo dele.", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 15),
          TextField(onChanged: (v) => novoNome = v, decoration: const InputDecoration(labelText: "Nome do NOVO Síndico(a)", border: OutlineInputBorder())), const SizedBox(height: 10),
          TextField(onChanged: (v) => novoEmail = v.trim().toLowerCase(), decoration: const InputDecoration(labelText: "E-mail do NOVO Síndico(a)", border: OutlineInputBorder())),
        ])),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          enviando ? const CircularProgressIndicator() : ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async {
            if (novoNome.isEmpty || novoEmail.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos!"))); return; }
            setStateSB(() => enviando = true);
            try {
              final logRef = await FirebaseFirestore.instance.collection('transferencias_gestao').add({'condominio_nome': dataAtual['condominio'], 'condominio_id': dataAtual['id_condominio'], 'sindico_antigo_email': doc.id, 'sindico_antigo_nome': dataAtual['nome'], 'sindico_novo_email': novoEmail, 'sindico_novo_nome': novoNome, 'solicitado_por': operadorLogado, 'data_solicitacao': FieldValue.serverTimestamp(), 'status': 'pendente'});
              await doc.reference.update({'transferencia_pendente': {'log_id': logRef.id, 'novo_email': novoEmail, 'novo_nome': novoNome, 'solicitado_por': operadorLogado}});
              if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Solicitação enviada! Aguardando aceite do síndico atual."), backgroundColor: Colors.green)); }
            } catch (e) { setStateSB(() => enviando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: colorScheme.error)); }
          }, child: const Text("SOLICITAR"))
        ],
      );
    }));
  }

  Widget _buildAbaCondos() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(children:[
      Container(padding: const EdgeInsets.all(15), color: colorScheme.surfaceContainerHighest, child: Wrap(spacing: 10, alignment: WrapAlignment.spaceAround, children: const [Text("Condomínios e Licenças SaaS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])),
      Expanded(child: StreamBuilder<QuerySnapshot>(stream: _sindicosStream, builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Erro ao carregar dados."));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(itemCount: snapshot.data!.docs.length, itemBuilder: (context, index) {
          final doc = snapshot.data!.docs[index], data = doc.data() as Map<String, dynamic>;
          final condoNome = data['condominio'] ?? "N/D", sindicoNome = data['nome'] ?? "N/D", ativo = data['servico_ativo'] ?? false, planoAtual = data['plano_id'] ?? 'Sem Plano';
          String diasStr = "Pendente"; Color corDias = colorScheme.onSurface;
          if (data['data_expiracao'] != null) {
             try {
               final d = (data['data_expiracao'] as Timestamp).toDate(); final dias = d.difference(DateTime.now()).inDays; diasStr = "$dias d";
               if (dias <= 7) corDias = Colors.orange; if (dias < 0) { diasStr = "Vencido"; corDias = colorScheme.error; }
             } catch (_) { diasStr = "Erro"; }
          }
          final temTransferencia = data['transferencia_pendente'] != null;

          return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 15, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children:[
            Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
              FittedBox(fit: BoxFit.scaleDown, child: Text(condoNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              FittedBox(fit: BoxFit.scaleDown, child: Text("Síndico: $sindicoNome")),
              FittedBox(fit: BoxFit.scaleDown, child: Text("ID Cliente: ${data['id_condominio']}", style: const TextStyle(fontSize: 10, color: Colors.grey))),
              if (data['administradora_vinculada'] != null) Container(margin: const EdgeInsets.only(top: 5), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(4)), child: Text("Gerido por Administradora", style: TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 10, fontWeight: FontWeight.bold))),
              if (temTransferencia) Container(margin: const EdgeInsets.only(top: 5), padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(4)), child: FittedBox(fit: BoxFit.scaleDown, child: Text("⏳ Aguardando aceite de transferência", style: TextStyle(color: colorScheme.onTertiaryContainer, fontSize: 10, fontWeight: FontWeight.bold))))
            ]),
            FittedBox(fit: BoxFit.scaleDown, child: Text("Plano: $planoAtual", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary))),
            FittedBox(fit: BoxFit.scaleDown, child: Text("Expira em: $diasStr", style: TextStyle(color: corDias, fontWeight: FontWeight.bold))),
            Switch(value: ativo, onChanged: (v) => doc.reference.update({'servico_ativo': v})),
            FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children:[
              IconButton(icon: Icon(Icons.view_sidebar, color: colorScheme.secondary), tooltip: "Personalizar Menus", onPressed: () => _modalEditarMenusUsuario(doc)),
              IconButton(icon: Icon(Icons.swap_horiz, color: colorScheme.tertiary), tooltip: "Transferir Gestão (Síndico p/ Síndico)", onPressed: () => _modalTransferirGestao(doc)),
              IconButton(icon: Icon(Icons.edit, color: colorScheme.primary), tooltip: "Plano e Licença", onPressed: () => _modalEditarCondominio(doc)),
              IconButton(icon: Icon(Icons.delete_forever, color: colorScheme.error), tooltip: "Excluir Definitivamente", onPressed: () => _confirmarExclusaoCondominio(doc)),
            ])),
          ])));
        });
      }))
    ]);
  }

  void _modalEditarCondominio(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    String planoSelecionado = data['plano_id'] ?? '';
    int diasAdicionais = 30;
    final planosSnap = await FirebaseFirestore.instance.collection('planos').get();
    if (!mounted) return;
    final listaPlanos = planosSnap.docs.map((d) => d.id).toList();

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) => AlertDialog(
      title: FittedBox(fit: BoxFit.scaleDown, child: Text("Gerenciar: ${data['condominio']}")),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[
        const Text("Definir Plano de Acesso:", style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(isExpanded: true, hint: const Text("Selecione um plano"), value: listaPlanos.contains(planoSelecionado) ? planoSelecionado : null, items: listaPlanos.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setStateSB(() => planoSelecionado = v!)),
        const SizedBox(height: 20), const Text("Renovar/Alterar Validade:", style: TextStyle(fontWeight: FontWeight.bold)),
        TextField(keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Adicionar dias a partir de hoje"), onChanged: (v) => diasAdicionais = int.tryParse(v) ?? 30)
      ]),
      actions:[
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary), onPressed: () async {
          await doc.reference.update({'plano_id': planoSelecionado, 'data_expiracao': Timestamp.fromDate(DateTime.now().add(Duration(days: diasAdicionais))), 'servico_ativo': true});
          if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Condomínio atualizado!"))); }
        }, child: const Text("SALVAR"))
      ],
    )));
  }

  void _confirmarExclusaoCondominio(DocumentSnapshot doc) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text("ATENÇÃO: Exclusão Permanente", style: TextStyle(color: Theme.of(context).colorScheme.error)),
      content: const Text("Excluir este Síndico cortará IMEDIATAMENTE o acesso de toda a portaria e de todos os moradores deste condomínio. Tem certeza?"),
      actions:[
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError), onPressed: () async {
          try {
            for(final col in ['usuarios', 'encomendas', 'portoes', 'cameras', 'idboxes', 'idfaces', 'visitantes', 'areas_comuns', 'reservas', 'fila_espera', 'notificacoes', 'auditoria', 'convites_vip', 'acessos_vip']) {
               final snap = await FirebaseFirestore.instance.collection(col).where('sindico_vinculado', isEqualTo: doc.id).get();
               if (snap.docs.isNotEmpty) { int i = 0; while (i < snap.docs.length) { final batch = FirebaseFirestore.instance.batch(); final chunkEnd = (i + 500 < snap.docs.length) ? i + 500 : snap.docs.length; for (int j = i; j < chunkEnd; j++) batch.delete(snap.docs[j].reference); await batch.commit(); i += 500; } }
            }
            await doc.reference.delete(); 
            if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Condomínio e todos os dados foram apagados."))); Navigator.pop(ctx); }
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)))); }
        }, child: const Text("EXCLUIR"))
      ],
    ));
  }

  Widget _abaPlanos() {
    final colorScheme = Theme.of(context).colorScheme;
    final keysFuncionalidades = ['encomendas', 'estoque', 'visitantes', 'facial', 'cameras', 'portoes', 'reservas', 'gestao', 'auditoria'];
    final nomesFuncionalidades = {'encomendas': 'Recepção de Encomendas', 'estoque': 'Inventário e Estoque', 'visitantes': 'Controle de Visitantes e VIP', 'facial': 'Reconhecimento Facial e Biometria', 'cameras': 'Mosaico de Câmeras Intelbras', 'portoes': 'Controle de Relés e Portões', 'reservas': 'Gestão de Áreas Comuns', 'gestao': 'Gestão de Moradores e Porteiros', 'auditoria': 'Histórico e Auditoria Avançada'};

    void modalCriarPlano({DocumentSnapshot? doc}) {
      String nomePlano = doc?.id ?? ""; double valorPlano = 0.0; Map<String, bool> funcs = {};
      if (doc != null) { final data = doc.data() as Map<String, dynamic>; funcs = Map<String, bool>.from(data['funcionalidades'] ?? {}); valorPlano = double.tryParse(data['valor']?.toString() ?? '0') ?? 0.0; } else { for (var k in keysFuncionalidades) funcs[k] = false; }

      showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) => AlertDialog(
        title: FittedBox(fit: BoxFit.scaleDown, child: Text(doc == null ? "Novo Plano SaaS" : "Editar Plano: $nomePlano")),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children:[
          if (doc == null) TextField(onChanged: (v) => nomePlano = v, decoration: const InputDecoration(labelText: "Nome do Plano (Ex: Básico, Premium)")), const SizedBox(height: 10),
          TextField(controller: TextEditingController(text: valorPlano > 0 ? valorPlano.toStringAsFixed(2) : ""), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Valor Mensal (R\$)", hintText: "Ex: 149.90", prefixText: "R\$ ", border: OutlineInputBorder()), onChanged: (v) => valorPlano = double.tryParse(v.replaceAll(',', '.')) ?? 0.0), const SizedBox(height: 20),
          const Text("Módulos Ativos:", style: TextStyle(fontWeight: FontWeight.bold)), ...keysFuncionalidades.map((k) => SwitchListTile(title: Text(nomesFuncionalidades[k]!, style: const TextStyle(fontSize: 14)), value: funcs[k] ?? false, activeThumbColor: colorScheme.primary, onChanged: (v) => setStateSB(() => funcs[k] = v)))
        ]))),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async { if (nomePlano.isNotEmpty) { await FirebaseFirestore.instance.collection('planos').doc(nomePlano).set({'funcionalidades': funcs, 'valor': valorPlano}); if (mounted) Navigator.pop(ctx); } }, child: const Text("SALVAR"))
        ],
      )));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: modalCriarPlano, icon: const Icon(Icons.add), label: const Text("Criar Plano")),
      body: Column(children:[
        const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text("Gerenciador de Planos de Assinatura", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: _planosStream, builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text("Erro ao carregar planos."));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhum plano configurado."));
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, itemBuilder: (context, index) {
            final doc = snap.data!.docs[index], data = doc.data() as Map<String, dynamic>, funcs = data['funcionalidades'] ?? {}, ativas = funcs.values.where((v) => v == true).length, valorPlano = double.tryParse(data['valor']?.toString() ?? '0') ?? 0.0;
            return Card(child: ListTile(
              leading: Icon(Icons.verified, color: colorScheme.primary, size: 40),
              title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(doc.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Módulos liberados: $ativas | Valor: R\$ ${valorPlano.toStringAsFixed(2)}")),
              trailing: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children:[IconButton(icon: Icon(Icons.edit, color: colorScheme.primary), onPressed: () => modalCriarPlano(doc: doc)), IconButton(icon: Icon(Icons.delete, color: colorScheme.error), onPressed: () => doc.reference.delete())])),
            ));
          });
        }))
      ]),
    );
  }

  Widget _abaEquipeMaster() {
    void modalAddMembro() {
      String nome = "", email = "", senha = "", perfilSelecionado = 'master'; bool criando = false, ocultarSenhaModal = true;
      showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text("Novo Membro da Equipe"),
          content: Column(mainAxisSize: MainAxisSize.min, children:[
            DropdownButton<String>(isExpanded: true, value: perfilSelecionado, items: const [DropdownMenuItem(value: 'master', child: Text("Administrador Master")), DropdownMenuItem(value: 'tecnico', child: Text("Técnico de Campo (Hardware)"))], onChanged: (v) => setStateSB(() => perfilSelecionado = v!)),
            TextField(onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: "Nome")),
            TextField(onChanged: (v) => email = v.toLowerCase().trim(), decoration: const InputDecoration(labelText: "E-mail de Acesso")),
            TextField(onChanged: (v) => senha = v, obscureText: ocultarSenhaModal, decoration: InputDecoration(labelText: "Senha", suffixIcon: IconButton(icon: Icon(ocultarSenhaModal ? Icons.visibility_off : Icons.visibility), onPressed: () => setStateSB(() => ocultarSenhaModal = !ocultarSenhaModal)))),
          ]),
          actions:[
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
            criando ? const CircularProgressIndicator() : ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async {
              if (email.isNotEmpty && senha.isNotEmpty) {
                setStateSB(() => criando = true);
                try {
                  final resultado = await FirebaseService.criarUsuarioSaaS(email: email, senha: senha, nome: nome, perfil: perfilSelecionado);
                  if (mounted) { if (resultado['sucesso'] == true) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Membro criado com sucesso!"), backgroundColor: Colors.green)); } else { setStateSB(() => criando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(resultado['erro'])), backgroundColor: colorScheme.error)); } }
                } catch (e) { if (mounted) { setStateSB(() => criando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: colorScheme.error)); } }
              }
            }, child: const Text("ADICIONAR"))
          ],
        );
      }));
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: modalAddMembro, icon: const Icon(Icons.person_add), label: const Text("Novo Membro")),
      body: Column(children:[
        const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text("Equipe do Software", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('usuarios').where('perfil', whereIn:['master', 'tecnico']).snapshots(), builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text("Erro ao carregar equipe."));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const Center(child: Text("Equipe vazia."));
          final colorScheme = Theme.of(context).colorScheme;
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, itemBuilder: (context, index) {
            final doc = snap.data!.docs[index], data = doc.data() as Map<String, dynamic>, isTecnico = data['perfil'] == 'tecnico';
            return Card(child: ListTile(
              leading: CircleAvatar(backgroundColor: isTecnico ? colorScheme.secondary : colorScheme.primary, child: Icon(isTecnico ? Icons.handyman : Icons.admin_panel_settings, color: isTecnico ? colorScheme.onSecondary : colorScheme.onPrimary)),
              title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'] ?? 'Sem nome', style: const TextStyle(fontWeight: FontWeight.bold))),
              subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("${data['email']} - ${isTecnico ? 'TÉCNICO' : 'MASTER'}")),
              trailing: IconButton(icon: Icon(Icons.delete, color: colorScheme.error), onPressed: () => doc.reference.delete()),
            ));
          });
        }))
      ]),
    );
  }

  Widget _abaAuditoriaTransferencias() {
    return Column(children:[
      const Padding(padding: EdgeInsets.all(16), child: Align(alignment: Alignment.centerLeft, child: Text("Auditoria Master de Transferências de Titularidade", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
      Expanded(child: _carregandoAuditoriaTransf ? const Center(child: CircularProgressIndicator()) : Builder(builder: (context) {
        if (_auditoriaTransfCache.isEmpty) return const Center(child: Text("Nenhuma transferência registrada."));
        final colorScheme = Theme.of(context).colorScheme;
        return ListView.builder(controller: _scrollControllerAuditoriaTransf, padding: const EdgeInsets.all(16), itemCount: _auditoriaTransfCache.length + (_buscandoNuvemAuditoriaTransf ? 1 : 0), itemBuilder: (ctx, i) {
          if (i == _auditoriaTransfCache.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Buscando histórico na nuvem...", style: TextStyle(color: Colors.grey))])));
          final data = _auditoriaTransfCache[i], status = data['status'] ?? 'pendente';
          Color corIcone = Colors.orange; IconData iconStatus = Icons.hourglass_empty;
          if (status == 'aprovada') { iconStatus = Icons.check_circle; corIcone = Colors.green; } else if (status == 'recusada') { iconStatus = Icons.cancel; corIcone = colorScheme.error; }
          final dataStr = data['data_solicitacao'] != null ? DateFormat('dd/MM/yyyy HH:mm').format((data['data_solicitacao'] as Timestamp).toDate()) : '';
          return Card(color: colorScheme.surface, elevation: 2, margin: const EdgeInsets.only(bottom: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: corIcone, width: status != 'pendente' ? 1 : 0.5)), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Row(children:[Icon(iconStatus, color: corIcone), const SizedBox(width: 10), Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Condomínio: ${data['condominio_nome']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))), const SizedBox(width: 10), Text(dataStr, style: const TextStyle(color: Colors.grey, fontSize: 12))]), const Divider(), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Síndico Anterior: ${data['sindico_antigo_nome']} (${data['sindico_antigo_email']})")), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Novo Titular: ${data['sindico_novo_nome']} (${data['sindico_novo_email']})")), const SizedBox(height: 10), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Status: ${status.toUpperCase()} (Solicitado por: ${data['solicitado_por']})", style: TextStyle(fontWeight: FontWeight.bold, color: corIcone)))])));
        });
      }))
    ]);
  }
}

// ============================================================================
// PARTE 5 - TÉCNICO E HARDWARE (INFRAESTRUTURA FÍSICA)
// ============================================================================

class GerenciadorDeTunel {
  static Process? _cfProcess, _mtxProcess;
  static HttpServer? _servidorLocalParaPlaca;
  static bool _iniciado = false;
  static String _sindicoAtivo = "";
  static StreamSubscription<QuerySnapshot>? _ouvinteComandosIot, _ouvinteFacesIot;
  static final Set<String> _comandosProcessadosLocais = {}, _tokensBluetoothUsados = {};
  static final Map<String, int> _ultimaAberturaReleLocal = {};

  static void registrarMovimentoRele(String rele) => _ultimaAberturaReleLocal[rele] = DateTime.now().millisecondsSinceEpoch;
  static bool isReleEmMovimento(String rele, int tempo) => _ultimaAberturaReleLocal.containsKey(rele) && (DateTime.now().millisecondsSinceEpoch - _ultimaAberturaReleLocal[rele]! < (tempo * 1000));

  static Future<void> iniciar(String sindico) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows && !_iniciado) {
      _iniciado = true; _sindicoAtivo = sindico;
      try {
        try { await Process.run('taskkill', ['/F', '/IM', 'cloudflared.exe', '/T']); } catch (_) {}
        try { await Process.run('taskkill', ['/F', '/IM', 'logichome_video.exe', '/T']); } catch (_) {}
        await Future.delayed(const Duration(seconds: 1));
        await _extrairOperarios("cloudflared.exe"); await _extrairOperarios("logichome_video.exe");
        await _garantirConversorRodando(); await _iniciarCloudflare();
        _iniciarOuvintePortoesLocais(); _iniciarOuvinteFacesLocais(); _iniciarServidorParaPlacaResponderBluetooth();
      } catch (e) { debugPrint("Erro fatal ao iniciar Túnel Diamante: $e"); }
    }
  }

  static Future<void> reiniciarTudo(String sindico) async { debugPrint("🔄 Reiniciando os motores..."); desligarTudo(); await Future.delayed(const Duration(seconds: 2)); await iniciar(sindico); }

  static void _iniciarServidorParaPlacaResponderBluetooth() async {
    if (_servidorLocalParaPlaca != null) return;
    try {
      _servidorLocalParaPlaca = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
      debugPrint("🛡️ [SERVIDOR LOCAL] PC ouvindo a Placa na Porta 8080...");
      
      _servidorLocalParaPlaca!.listen((HttpRequest request) async {
        if (request.uri.path == '/check_access') {
          String payloadCripto = request.uri.queryParameters['email'] ?? '';
          String rele = request.uri.queryParameters['rele'] ?? '';
          
          String email = "";
          bool isOffline = false;

          // MÁGICA SUPREMA: Descriptografa o código alienígena para barrar hackers e "Replay Attacks"
          String descriptografado = CryptoHelper.descriptografar(payloadCripto);
          
          if (descriptografado.isNotEmpty && descriptografado.contains(';')) {
             List<String> partes = descriptografado.split(';');
             email = partes[0];
             int timestampRequisicao = int.tryParse(partes[1]) ?? 0;
             if (partes.length > 2 && partes[2] == "OFF") isOffline = true;
             int timestampAtual = DateTime.now().millisecondsSinceEpoch;
             
             // Tolerância rigorosa de 30 segundos (30.000 ms). Mata o Replay Attack via limite de tempo!
             if ((timestampAtual - timestampRequisicao).abs() > 30000) {
                 debugPrint("❌ [SERVIDOR LOCAL] HACKER DETECTADO! Tentativa de Replay Attack (Tempo expirado).");
                 request.response.statusCode = 403;
                 request.response.write("BLOCKED");
                 await request.response.close();
                 return;
             }
             
             // MÁGICA: Verifica se este pacote EXATO já foi usado nos últimos segundos (Mata a Clonagem Imediata!)
             if (_tokensBluetoothUsados.contains(payloadCripto)) {
                 debugPrint("❌ [SERVIDOR LOCAL] HACKER DETECTADO! Token clonado (Já utilizado).");
                 request.response.statusCode = 403;
                 request.response.write("BLOCKED");
                 await request.response.close();
                 return;
             }
             
             // Adiciona na lista negra para não ser usado de novo
             _tokensBluetoothUsados.add(payloadCripto);
             
             // Limpa tokens velhos da memória para não estourar a RAM do PC do porteiro
             if (_tokensBluetoothUsados.length > 50) _tokensBluetoothUsados.clear();
             
          } else {
             debugPrint("❌ [SERVIDOR LOCAL] Carga inválida ou sem criptografia!");
             request.response.statusCode = 403;
             request.response.write("ERR");
             await request.response.close();
             return;
          }

          debugPrint("🧐 [SERVIDOR LOCAL] Placa perguntou via BLE: $email pode abrir o relé $rele?");
          
          try {
            // Consulta o Firebase! Se não tiver internet, ele usa a memória Cache do PC.
            DocumentSnapshot docMorador;
            try {
              docMorador = await FirebaseFirestore.instance.collection('usuarios').doc(email).get(const GetOptions(source: Source.server));
            } catch (_) {
              docMorador = await FirebaseFirestore.instance.collection('usuarios').doc(email).get(const GetOptions(source: Source.cache));
            }

            if (docMorador.exists) {
              var data = docMorador.data() as Map<String, dynamic>;
              if (data['status'] == 'aprovado' && data['servico_ativo'] == true) {
                int agora = DateTime.now().millisecondsSinceEpoch;
                
                // MÁGICA: O Computador barra o Bluetooth se alguém metralhar o botão
                if (_ultimaAberturaReleLocal.containsKey(rele) && (agora - _ultimaAberturaReleLocal[rele]! < 15000)) {
                  request.response.statusCode = 429; 
                  request.response.write("MOV");
                  debugPrint("⚠️ [SERVIDOR LOCAL] Respondeu: EM MOVIMENTO (Anti-Spam)!");
                } else {
                  _ultimaAberturaReleLocal[rele] = agora;
                  request.response.statusCode = 200; // 200 = APROVADO!
                  request.response.write("OK");
                  await request.response.close();
                  debugPrint("✅ [SERVIDOR LOCAL] Respondeu: APROVADO e Portão Aberto!");
                  
                  // MÁGICA 2: O Computador tenta descobrir o nome do portão (Com ou Sem internet)
                  String nomeDoPortaoEncontrado = "Relé $rele";
                  try {
                    final snapPortao = await FirebaseFirestore.instance.collection('portoes').where('sindico_vinculado', isEqualTo: _sindicoAtivo).where('codigo', isEqualTo: rele).get();
                    if (snapPortao.docs.isNotEmpty) {
                      nomeDoPortaoEncontrado = snapPortao.docs.first.data()['nome'] ?? "Relé $rele";
                      for (var d in snapPortao.docs) {
                        d.reference.update({'ultima_abertura': FieldValue.serverTimestamp()}).catchError((_) {});
                      }
                    }
                  } catch (e) {
                    debugPrint("⚠️ Sem internet para buscar o nome do portão. Usando o nome padrão.");
                  }
                  
                  // MÁGICA 3: O Computador grava a auditoria APENAS se o morador estiver 100% offline.
                  // Evita logs duplicados, pois se ele estiver online, o próprio celular dele gravará a auditoria "Abertura Bluetooth".
                  if (isOffline) {
                    FirebaseFirestore.instance.collection('auditoria').add({
                      'sindico_vinculado': _sindicoAtivo,
                      'operador': data['nome'] ?? email,
                      'acao': 'Validação de Bluetooth (Servidor Local)',
                      'modulo': 'Controle de Acessos',
                      'detalhes': 'O Servidor da Portaria validou a credencial do morador (Portão: $nomeDoPortaoEncontrado).',
                      'data_hora': FieldValue.serverTimestamp(),
                      'plataforma': 'Servidor Windows',
                    }).then((_) {}).catchError((_) {});
                  }
                }
              } else {
                request.response.statusCode = 403; // 403 = NEGADO/BLOQUEADO!
                request.response.write("BLOCKED");
                debugPrint("❌ [SERVIDOR LOCAL] Respondeu: BLOQUEADO!");
              }
            } else {
              request.response.statusCode = 403;
              request.response.write("BLOCKED");
            }
          } catch (e) {
            request.response.statusCode = 500;
            request.response.write("ERR");
          }
          await request.response.close();
        }
      });
    } catch (e) {
      debugPrint("Erro ao abrir porta 8080: $e");
    }
  }

  static void _iniciarOuvintePortoesLocais() {
    _ouvinteComandosIot?.cancel();
    final horaInicioServidor = DateTime.now();

    _ouvinteComandosIot = FirebaseFirestore.instance.collection('comandos_iot').where('sindico_vinculado', isEqualTo: _sindicoAtivo).where('status', whereIn: ['pendente', 'processando_no_hardware']).snapshots().listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final dataComando = change.doc.data() as Map<String, dynamic>, idComando = change.doc.id;
          
          if (_comandosProcessadosLocais.contains(idComando) || dataComando['status'] == 'concluido' || dataComando['status'] == 'cancelado' || (dataComando['id_dispositivo'] ?? '').isEmpty) continue;

          // PROTEÇÃO CONTRA FILA ZUMBI (Não deixa abrir se for um comando velho preso na nuvem)
          DateTime? tCmd;
          if (dataComando['data_hora'] != null) tCmd = (dataComando['data_hora'] as Timestamp).toDate();
          else if (dataComando['timestamp'] != null) tCmd = (dataComando['timestamp'] as Timestamp).toDate();
          
          if (tCmd != null && DateTime.now().difference(tCmd).inSeconds > 15) {
             _comandosProcessadosLocais.add(idComando);
             change.doc.reference.update({'status': 'cancelado'}).catchError((_) {});
             continue;
          } else if (tCmd == null && DateTime.now().difference(horaInicioServidor).inSeconds < 5 && change.type == DocumentChangeType.added) {
             _comandosProcessadosLocais.add(idComando);
             change.doc.reference.update({'status': 'cancelado'}).catchError((_) {});
             continue;
          }

          _comandosProcessadosLocais.add(idComando);
          change.doc.reference.update({'status': 'processando_local'}).then((_) {}, onError: (_) {});
          
          final snapPlaca = await FirebaseFirestore.instance.collection('idboxes').where('sindico_vinculado', isEqualTo: _sindicoAtivo).where('id_unico', isEqualTo: dataComando['id_dispositivo']).limit(1).get();
          if (snapPlaca.docs.isNotEmpty) {
            final dataPlaca = snapPlaca.docs.first.data(), ipLocal = dataPlaca['ip_local'] ?? '';
            if (ipLocal.isNotEmpty) {
              if (dataPlaca['marca'] == 'control_id' && await _dispararControlIdLocal(ipLocal, dataPlaca['usuario'] ?? 'admin', dataPlaca['senha_criptografada'] != null ? CryptoHelper.descriptografar(dataPlaca['senha_criptografada']) : '', dataComando['rele'] ?? '1')) {
                await change.doc.reference.update({'status': 'concluido', 'data_execucao': FieldValue.serverTimestamp(), 'via_local': true});
              } else await change.doc.reference.update({'status': 'cancelado'}).then((_) {}, onError: (_) {});
            } else await change.doc.reference.update({'status': 'cancelado'}).then((_) {}, onError: (_) {});
          } else await change.doc.reference.update({'status': 'cancelado'}).then((_) {}, onError: (_) {});
        }
      }
    });
  }

  static Future<bool> _dispararControlIdLocal(String ip, String usuario, String senha, String rele) async {
    for (int tentativa = 1; tentativa <= 2; tentativa++) {
      try {
        final responseLogin = await http.post(Uri.parse('http://$ip/login.fcgi'), headers: {'Content-Type': 'application/json', 'Connection': 'close'}, body: jsonEncode({"login": usuario.isEmpty ? "admin" : usuario, "password": senha.isEmpty ? "admin" : senha})).timeout(const Duration(seconds: 7));
        if (responseLogin.statusCode == 200) {
          final sessionToken = jsonDecode(responseLogin.body)['session'];
          if (sessionToken != null && (await http.post(Uri.parse('http://$ip/execute_actions.fcgi?session=$sessionToken'), headers: {'Content-Type': 'application/json', 'Connection': 'close'}, body: jsonEncode({"actions": [{"action": "sec_box", "parameters": "id=$rele, reason=3"}, {"action": "door", "parameters": "door=$rele"}]})).timeout(const Duration(seconds: 7))).statusCode == 200) return true;
        }
      } catch (_) { if (tentativa == 1) await Future.delayed(const Duration(milliseconds: 500)); }
    }
    return false;
  }

  static Future<void> _extrairOperarios(String nomeArquivo) async {
    final file = File('${(await Directory('${(await getApplicationDocumentsDirectory()).path}\\LogicHomeApp').create(recursive: true)).path}\\$nomeArquivo');
    if (!await file.exists()) {
      try { await file.writeAsBytes((await rootBundle.load('assets/bin/$nomeArquivo')).buffer.asUint8List(), flush: true); } catch (_) {}
    }
  }

  static Future<void> _iniciarCloudflare() async {
    final pastaLogicHome = Directory('${(await getApplicationDocumentsDirectory()).path}\\LogicHomeApp');
    final data = (await FirebaseFirestore.instance.collection('usuarios').doc(_sindicoAtivo).get()).data();
    final tokenCloudflare = data?['cloudflare_token'] ?? "", urlFixa = data?['cloudflare_url_fixa'] ?? "";

    if (tokenCloudflare.isNotEmpty && urlFixa.isNotEmpty) {
      _cfProcess = await Process.start('cmd', ['/c', '${pastaLogicHome.path}\\cloudflared.exe', 'tunnel', '--no-autoupdate', 'run', '--token', tokenCloudflare.trim()]);
      _cfProcess!.stdout.transform(utf8.decoder).listen((_) {}); _cfProcess!.stderr.transform(utf8.decoder).listen((_) {});
      urlTunelVideoAtiva = urlFixa; await Future.delayed(const Duration(seconds: 3));
      await FirebaseFirestore.instance.collection('usuarios').doc(_sindicoAtivo).update({'url_tunel_video': urlTunelVideoAtiva, 'tunel_online': true});
    } else {
      _cfProcess = await Process.start('${pastaLogicHome.path}\\cloudflared.exe', ['tunnel', '--url', 'http://localhost:8888']);
      void interceptar(String l) { final match = RegExp(r'https://[a-zA-Z0-9-]+\.trycloudflare\.com').firstMatch(l); if (match != null && urlTunelVideoAtiva.isEmpty) { urlTunelVideoAtiva = match.group(0)!; FirebaseFirestore.instance.collection('usuarios').doc(_sindicoAtivo).update({'url_tunel_video': urlTunelVideoAtiva, 'tunel_online': true}); } }
      _cfProcess!.stdout.transform(utf8.decoder).listen((t) { for (var l in t.split('\n')) interceptar(l); });
      _cfProcess!.stderr.transform(utf8.decoder).listen((t) { for (var l in t.split('\n')) interceptar(l); });
    }
  }

  static Future<void> _garantirConversorRodando() async {
    if (_mtxProcess != null) return;
    try {
      final pastaLogicHome = Directory('${(await getApplicationDocumentsDirectory()).path}\\LogicHomeApp');
      if (!await File('${pastaLogicHome.path}\\logichome_video.exe').exists()) return;
      final snapCameras = await FirebaseFirestore.instance.collection('cameras').where('sindico_vinculado', isEqualTo: _sindicoAtivo).get();
      final ymlContent = StringBuffer("api: yes\napiAddress: 127.0.0.1:9997\nhlsAddress: 127.0.0.1:8888\nhlsAlwaysRemux: yes\nhlsVariant: lowLatency\nhlsSegmentDuration: 1s\nrtspAddress: 127.0.0.1:8555\nrtmpAddress: 127.0.0.1:1936\nwebrtcAddress: 127.0.0.1:8892\nwebrtcLocalUDPAddress: 127.0.0.1:8195\nrtpAddress: 127.0.0.1:8002\nrtcpAddress: 127.0.0.1:8003\npaths:\n");
      if (snapCameras.docs.isEmpty) ymlContent.write("  all:\n"); else {
        for (var doc in snapCameras.docs) {
          final data = doc.data(); String senhaPlayer = data['senha'] ?? '';
          if (data['senha_criptografada'] == true) senhaPlayer = CryptoHelper.descriptografar(senhaPlayer); else if (data['senha_ofuscada'] == true) try { senhaPlayer = utf8.decode(base64Decode(senhaPlayer)); } catch (_) {}
          ymlContent.write("  ${doc.id}:\n    source: \"rtsp://${Uri.encodeComponent(data['usuario'] ?? 'admin')}:${Uri.encodeComponent(senhaPlayer)}@${data['ip'] ?? ''}:${data['porta_rtsp'] ?? '554'}/cam/realmonitor?channel=${data['canal'] ?? '1'}&subtype=1\"\n    sourceOnDemand: ${(data['visivel_morador'] ?? false) ? 'no' : 'yes'}\n");
        }
        ymlContent.write("  all_others:\n");
      }
      final configFile = File('${pastaLogicHome.path}\\logichome_video.yml'); await configFile.writeAsString(ymlContent.toString());
      _mtxProcess = await Process.start('${pastaLogicHome.path}\\logichome_video.exe', [configFile.path]);
      _mtxProcess!.stdout.transform(utf8.decoder).listen((_) {}); _mtxProcess!.stderr.transform(utf8.decoder).listen((_) {});
      await Future.delayed(const Duration(seconds: 3));
    } catch (_) {}
  }

  static void _iniciarOuvinteFacesLocais() {
    _ouvinteFacesIot?.cancel();
    _ouvinteFacesIot = FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: _sindicoAtivo).where('perfil', isEqualTo: 'morador').where('status', isEqualTo: 'aprovado').where('sincronizado_catraca', isEqualTo: false).snapshots().listen((snap) async {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) {
          final dataMorador = change.doc.data() as Map<String, dynamic>;
          if (dataMorador['foto_storage_url'] == null) continue;
          try {
            final responseImg = await http.get(Uri.parse(dataMorador['foto_storage_url'])); if (responseImg.statusCode != 200) continue;
            final base64Image = base64Encode(responseImg.bodyBytes), snapFaces = await FirebaseFirestore.instance.collection('idfaces').where('sindico_vinculado', isEqualTo: _sindicoAtivo).get();
            if (snapFaces.docs.isEmpty) continue;
            int sucesso = 0;
            for (var catraca in snapFaces.docs) {
              final cData = catraca.data(); if (cData['marca'] != 'control_id') continue;
              final ipLocal = cData['ip_local'], responseLogin = await http.post(Uri.parse('http://$ipLocal/login.fcgi'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"login": cData['usuario'] ?? 'admin', "password": cData['senha_criptografada'] == true ? CryptoHelper.descriptografar(cData['senha'] ?? 'admin') : (cData['senha'] ?? 'admin')})).timeout(const Duration(seconds: 5));
              if (responseLogin.statusCode == 200) {
                final token = jsonDecode(responseLogin.body)['session'], idNumerico = change.doc.id.hashCode.abs();
                await http.post(Uri.parse('http://$ipLocal/create_objects.fcgi?session=$token'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"object": "users", "values": [{"id": idNumerico, "name": dataMorador['nome'], "registration": change.doc.id}]}));
                if ((await http.post(Uri.parse('http://$ipLocal/user_set_image.fcgi?session=$token'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"user_id": idNumerico, "image": base64Image, "timestamp": DateTime.now().millisecondsSinceEpoch ~/ 1000})).timeout(const Duration(seconds: 15))).statusCode == 200) sucesso++;
              }
            }
            if (sucesso > 0) await change.doc.reference.update({'sincronizado_catraca': true});
          } catch (_) {}
        }
      }
    });
  }

  static void desligarTudo() {
    _ouvinteFacesIot?.cancel(); _ouvinteComandosIot?.cancel(); _ouvinteComandosIot = null; _comandosProcessadosLocais.clear();
    _cfProcess?.kill(); _cfProcess = null; _mtxProcess?.kill(); _mtxProcess = null;
    _servidorLocalParaPlaca?.close(force: true); _servidorLocalParaPlaca = null;
    _iniciado = false; urlTunelVideoAtiva = "";
    try { Process.run('taskkill', ['/F', '/IM', 'cloudflared.exe', '/T']); Process.run('taskkill', ['/F', '/IM', 'logichome_video.exe', '/T']); } catch (_) {}
    if (_sindicoAtivo.isNotEmpty) { FirebaseFirestore.instance.collection('usuarios').doc(_sindicoAtivo).update({'tunel_online': false, 'url_tunel_video': FieldValue.delete()}); _sindicoAtivo = ""; }
  }
}

class TelaConfiguracaoTunel extends StatefulWidget {
  final String emailSindico;
  const TelaConfiguracaoTunel({super.key, required this.emailSindico});
  @override
  State<TelaConfiguracaoTunel> createState() => _TelaConfiguracaoTunelState();
}

class _TelaConfiguracaoTunelState extends State<TelaConfiguracaoTunel> {
  final _tokenCtrl = TextEditingController(), _urlCtrl = TextEditingController();
  bool _salvando = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(children: [
        const Padding(padding: EdgeInsets.all(16.0), child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: Text("Servidor de Vídeo (Túnel 4G)", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))))),
        Expanded(child: StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('usuarios').doc(widget.emailSindico).snapshots(), builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text("Erro de conexão."));
          if (!snap.hasData || !snap.data!.exists) return const Center(child: CircularProgressIndicator());
          final data = snap.data!.data() as Map<String, dynamic>, isOnline = data['tunel_online'] == true;
          if (!_salvando) { _tokenCtrl.text = data['cloudflare_token'] ?? ''; _urlCtrl.text = data['cloudflare_url_fixa'] ?? ''; }
          return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: Padding(padding: const EdgeInsets.all(30), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.cloud_sync, size: 40, color: colorScheme.primary), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Cloudflare Zero Trust (Modo Produção)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text("Configure o túnel autenticado para liberar a visão das câmeras no 4G dos moradores.", style: TextStyle(color: colorScheme.onSurfaceVariant))])), Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), decoration: BoxDecoration(color: isOnline ? Colors.green.withValues(alpha:0.2) : Colors.red.withValues(alpha:0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: isOnline ? Colors.green : Colors.red)), child: Column(children: [Text(isOnline ? "TÚNEL ONLINE" : "TÚNEL OFFLINE", style: TextStyle(color: isOnline ? Colors.green : Colors.red, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(data['url_tunel_video'] ?? 'Nenhuma URL Ativa', style: TextStyle(fontSize: 10, color: colorScheme.onSurface))]))]), const Divider(height: 40),
            const Text("URL Pública Fixa (Public Hostname):", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), TextField(controller: _urlCtrl, decoration: const InputDecoration(hintText: "Ex: https://camera-condo-a.logichome.com.br", border: OutlineInputBorder(), prefixIcon: Icon(Icons.link))), const SizedBox(height: 20),
            const Text("Token de Instalação (Fornecido pela Cloudflare):", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), TextField(controller: _tokenCtrl, maxLines: 4, decoration: const InputDecoration(hintText: "Cole o token gigante (eyJh...)", border: OutlineInputBorder())), const SizedBox(height: 30),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20), backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), icon: _salvando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save), label: const Text("SALVAR CONFIGURAÇÃO E APLICAR", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)), onPressed: _salvando ? null : () async {
              setState(() => _salvando = true);
              try {
                await snap.data!.reference.update({'cloudflare_token': _tokenCtrl.text.trim(), 'cloudflare_url_fixa': _urlCtrl.text.trim()});
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configuração salva! Reinicie o aplicativo no PC da portaria para o novo túnel subir."), backgroundColor: Colors.green, duration: Duration(seconds: 5)));
              } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); }
              setState(() => _salvando = false);
            })), const SizedBox(height: 15),
            Container(padding: const EdgeInsets.all(15), color: Colors.orange.withValues(alpha:0.1), child: const Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 10), Expanded(child: Text("Nota: Deixe os campos em branco e salve se quiser forçar o sistema a voltar para o Modo de Testes (Túnel Anônimo TryCloudflare).", style: TextStyle(color: Colors.orange, fontSize: 12)))]))
          ]))));
        }))
      ]),
    );
  }
}

class TelaSelecaoCondominioTecnico extends StatefulWidget {
  const TelaSelecaoCondominioTecnico({super.key});
  @override
  State<TelaSelecaoCondominioTecnico> createState() => _TelaSelecaoCondominioTecnicoState();
}

class _TelaSelecaoCondominioTecnicoState extends State<TelaSelecaoCondominioTecnico> {
  String busca = "";

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Selecione o Condomínio"), actions:[const BotaoTrocarTema(), IconButton(icon: const Icon(Icons.logout), onPressed: () async { await FirebaseAuth.instance.signOut(); if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TelaLogin())); })]),
      body: Column(children:[
        Padding(padding: const EdgeInsets.all(16.0), child: TextField(onChanged: (v) => setState(() => busca = v.toLowerCase()), decoration: const InputDecoration(labelText: "Buscar Condomínio ou Síndico", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('usuarios').where('perfil', isEqualTo: 'sindico').snapshots(), builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text("Erro ao carregar dados."));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final lista = snap.data!.docs.where((d) { final data = d.data() as Map<String, dynamic>; return (data['condominio'] ?? "").toString().toLowerCase().contains(busca) || (data['nome'] ?? "").toString().toLowerCase().contains(busca); }).toList();
          if (lista.isEmpty) return const Center(child: Text("Nenhum condomínio encontrado."));
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: lista.length, itemBuilder: (context, index) {
            final doc = lista[index], data = doc.data() as Map<String, dynamic>;
            return Card(elevation: 3, margin: const EdgeInsets.only(bottom: 15), child: ListTile(leading: CircleAvatar(backgroundColor: colorScheme.primary, child: Icon(Icons.business, color: colorScheme.onPrimary)), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['condominio'] ?? "Sem Nome", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))), subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Síndico: ${data['nome']} | ID: ${data['id_condominio']}")), trailing: const Icon(Icons.arrow_forward_ios), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PainelEstrutural(perfil: 'tecnico', emailSindico: doc.id, funcionalidadesPermitidas: const {})))));
          });
        }))
      ]),
    );
  }
}

class TelaHardwareIDBox extends StatefulWidget {
  final String emailSindico;
  const TelaHardwareIDBox({super.key, required this.emailSindico});
  @override
  State<TelaHardwareIDBox> createState() => _TelaHardwareIDBoxState();
}

class _TelaHardwareIDBoxState extends State<TelaHardwareIDBox> {
  String _ipComputadorAtual = "Buscando IP...";

  @override
  void initState() { super.initState(); _buscarIpLocal(); }

  Future<void> _buscarIpLocal() async {
    try { for (var interface in await NetworkInterface.list()) for (var addr in interface.addresses) if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) { if (mounted) setState(() => _ipComputadorAtual = addr.address); return; } } catch (_) { if (mounted) setState(() => _ipComputadorAtual = "Desconhecido"); }
  }

  void _cadastrarIDBox() {
    String nome = "", idUnico = "", token = const Uuid().v4(), webhook = "https://webhookidbox-hhygy7dtpa-uc.a.run.app/", ipLocal = "", usuario = "admin", senha = "", marcaProtocolo = "control_id";
    bool ocultarSenha = true;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Registrar Placa / Módulo de Relé")),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[
          TextField(onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: "Nome do Dispositivo (Ex: Placa Portão Social)")), const SizedBox(height: 10),
          TextField(onChanged: (v) => idUnico = v.trim(), decoration: const InputDecoration(labelText: "ID Único (MAC Address ou Serial)")), const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorScheme.primary.withValues(alpha:0.5))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.speed, color: colorScheme.primary, size: 18), const SizedBox(width: 8), const Expanded(child: Text("Abertura Ultra-Rápida (Rede Local)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))]), const SizedBox(height: 5), const Text("Preencha para o Computador da Portaria abrir o portão instantaneamente sem depender do delay da nuvem.", style: TextStyle(fontSize: 11, color: Colors.grey)), const SizedBox(height: 15),
            DropdownButtonFormField<String>(isExpanded: true, initialValue: marcaProtocolo, decoration: const InputDecoration(labelText: "Marca / Protocolo", border: OutlineInputBorder()), items: const [DropdownMenuItem(value: "control_id", child: Text("Control iD (iDBox / iDAccess)")), DropdownMenuItem(value: "rele_generico", child: Text("Relé Genérico (HTTP GET)")), DropdownMenuItem(value: "nuvem_apenas", child: Text("Nenhum (Usar Apenas a Nuvem)"))], onChanged: (v) => setStateSB(() => marcaProtocolo = v!)), const SizedBox(height: 10),
            if (marcaProtocolo != "nuvem_apenas") ...[TextField(onChanged: (v) => ipLocal = v.trim(), decoration: const InputDecoration(labelText: "IP Local (Ex: 192.168.0.50)", border: OutlineInputBorder())), const SizedBox(height: 10), Row(children:[Expanded(child: TextField(controller: TextEditingController(text: usuario), onChanged: (v) => usuario = v.trim(), decoration: const InputDecoration(labelText: "Usuário", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(onChanged: (v) => senha = v.trim(), obscureText: ocultarSenha, decoration: InputDecoration(labelText: "Senha", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(ocultarSenha ? Icons.visibility_off : Icons.visibility), onPressed: () => setStateSB(() => ocultarSenha = !ocultarSenha)))))])]
          ])), const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blue.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withValues(alpha:0.5))), child: Row(children:[const Icon(Icons.computer, color: Colors.blue), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("IP Local deste Computador (Para copiar):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue)), Text(_ipComputadorAtual, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])), IconButton(icon: const Icon(Icons.copy, color: Colors.blue), tooltip: "Copiar IP Local", onPressed: () { Clipboard.setData(ClipboardData(text: _ipComputadorAtual)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("IP Local copiado!"))); })])), const SizedBox(height: 15),
          const Text("URL Webhook (Configure na placa):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Row(children:[Expanded(child: SelectableText(webhook, style: TextStyle(color: colorScheme.primary))), IconButton(icon: const Icon(Icons.copy, size: 20), tooltip: "Copiar URL", onPressed: () { Clipboard.setData(ClipboardData(text: webhook)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("URL do Webhook copiada!"))); })]), const SizedBox(height: 15),
          const Text("Token de Segurança (Bearer):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Row(children:[Expanded(child: SelectableText(token, style: const TextStyle(color: Colors.green))), IconButton(icon: const Icon(Icons.copy, size: 20), tooltip: "Copiar Token", onPressed: () { Clipboard.setData(ClipboardData(text: token)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Token copiado!"))); }), IconButton(icon: const Icon(Icons.refresh), tooltip: "Gerar Novo", onPressed: () => setStateSB(() => token = const Uuid().v4()))])
        ]))),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async {
            if (nome.isNotEmpty && idUnico.isNotEmpty) {
              await FirebaseFirestore.instance.collection('idboxes').add({'sindico_vinculado': widget.emailSindico, 'nome': nome, 'id_unico': idUnico, 'token': token, 'webhook': webhook, 'status': 'offline', 'marca': marcaProtocolo, 'ip_local': ipLocal, 'usuario': usuario, 'senha_criptografada': senha.isNotEmpty ? CryptoHelper.criptografar(senha) : "", 'data_registro': FieldValue.serverTimestamp()});
              if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Placa registrada com sucesso!"), backgroundColor: Colors.green)); }
            } else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Preencha o Nome e o ID Único!"), backgroundColor: colorScheme.error));
          }, child: const Text("SALVAR"))
        ],
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _cadastrarIDBox, icon: const Icon(Icons.memory), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("Vincular Placa IoT"))),
      body: Column(children:[
        const Padding(padding: EdgeInsets.all(16.0), child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: Text("Gerenciador de Hardware (Módulos e Relés)", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))))),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('idboxes').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots(), builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text("Erro ao carregar Placas."));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhuma placa configurada neste condomínio."));
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, itemBuilder: (context, index) {
            final doc = snap.data!.docs[index], data = doc.data() as Map<String, dynamic>, isOnline = data['status'] == 'online';
            return Card(elevation: 2, child: ListTile(leading: Icon(Icons.memory, color: isOnline ? Colors.green : Colors.grey, size: 40), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'], style: const TextStyle(fontWeight: FontWeight.bold))), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("ID: ${data['id_unico']} | IP: ${data['ip_local'] ?? 'Sem IP'}")), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Protocolo Local: ${(data['marca'] ?? 'control_id').toString().toUpperCase()}", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 11)))]), trailing: Row(mainAxisSize: MainAxisSize.min, children:[IconButton(icon: const Icon(Icons.copy), tooltip: "Copiar Token", onPressed: () { Clipboard.setData(ClipboardData(text: data['token'])); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Token copiado para a área de transferência!"))); }), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isOnline ? Colors.green.withValues(alpha:0.2) : colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(5)), child: Text(isOnline ? "ONLINE" : "OFFLINE", style: TextStyle(color: isOnline ? Colors.green : colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 10))), const SizedBox(width: 10), IconButton(icon: Icon(Icons.delete, color: colorScheme.error), onPressed: () => doc.reference.delete())])));
          });
        }))
      ])
    );
  }
}

class TelaHardwareFacial extends StatefulWidget {
  final String emailSindico;
  const TelaHardwareFacial({super.key, required this.emailSindico});
  @override
  State<TelaHardwareFacial> createState() => _TelaHardwareFacialState();
}

class _TelaHardwareFacialState extends State<TelaHardwareFacial> {
  void _cadastrarEquipamentoFacial() {
    String nome = "", ipLocal = "", usuario = "admin", senha = "", marca = "control_id"; bool ocultarSenha = true;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Registrar Equipamento Facial")),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text("ATENÇÃO: Este equipamento deve estar na mesma rede local (Wi-Fi/Cabo) do computador da portaria.", style: TextStyle(color: colorScheme.error, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 15),
          TextField(onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: "Nome do Equipamento (Ex: Catraca Social)", border: OutlineInputBorder())), const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: marca, decoration: const InputDecoration(labelText: "Marca/Protocolo", border: OutlineInputBorder()), items: const [DropdownMenuItem(value: "control_id", child: Text("Control iD (iDFace/iDAccess)")), DropdownMenuItem(value: "intelbras", child: Text("Intelbras / Hikvision (ISAPI)"))], onChanged: (v) => setStateSB(() => marca = v!)), const SizedBox(height: 10),
          TextField(onChanged: (v) => ipLocal = v.trim(), decoration: const InputDecoration(labelText: "IP Local (Ex: 192.168.0.150)", border: OutlineInputBorder())), const SizedBox(height: 10),
          Row(children:[Expanded(child: TextField(controller: TextEditingController(text: usuario), onChanged: (v) => usuario = v, decoration: const InputDecoration(labelText: "Usuário", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(onChanged: (v) => senha = v, obscureText: ocultarSenha, decoration: InputDecoration(labelText: "Senha", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(ocultarSenha ? Icons.visibility_off : Icons.visibility), onPressed: () => setStateSB(() => ocultarSenha = !ocultarSenha)))))])
        ])),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async {
            if (nome.isNotEmpty && ipLocal.isNotEmpty && senha.isNotEmpty) {
              await FirebaseFirestore.instance.collection('idfaces').add({'sindico_vinculado': widget.emailSindico, 'nome': nome, 'ip_local': ipLocal, 'usuario': usuario, 'senha': CryptoHelper.criptografar(senha), 'senha_criptografada': true, 'marca': marca, 'data_registro': FieldValue.serverTimestamp()});
              if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Equipamento facial registrado com segurança!"))); }
            } else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Preencha todos os campos!"), backgroundColor: colorScheme.error)); }
          }, child: const Text("SALVAR"))
        ],
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _cadastrarEquipamentoFacial, icon: const Icon(Icons.face), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("Adicionar Leitor Facial"))),
      body: Column(children:[
        const Padding(padding: EdgeInsets.all(16.0), child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: Text("Gerenciador de Leitores Faciais", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))))),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('idfaces').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots(), builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text("Erro ao carregar equipamentos."));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhum leitor facial configurado neste condomínio."));
          return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, itemBuilder: (context, index) {
            final doc = snap.data!.docs[index], data = doc.data() as Map<String, dynamic>;
            return Card(elevation: 2, child: ListTile(leading: Icon(Icons.document_scanner, color: colorScheme.primary, size: 40), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'], style: const TextStyle(fontWeight: FontWeight.bold))), subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("IP: ${data['ip_local']} | Marca: ${data['marca'].toString().toUpperCase()}")), trailing: IconButton(icon: Icon(Icons.delete, color: colorScheme.error), onPressed: () => doc.reference.delete())));
          });
        }))
      ])
    );
  }
}

class TelaPortoes extends StatefulWidget {
  final String emailSindico, perfil;
  const TelaPortoes({super.key, required this.emailSindico, required this.perfil});
  @override
  State<TelaPortoes> createState() => _TelaPortoesState();
}

class _TelaPortoesState extends State<TelaPortoes> {
  late Stream<QuerySnapshot> _portoesStream;
  List<DocumentSnapshot> _dispositivosiDBox = [], _camerasDisponiveis = [];

  @override
  void initState() { super.initState(); _portoesStream = FirebaseFirestore.instance.collection('portoes').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots(); _carregarDispositivos(); }

  void _carregarDispositivos() async {
    final snapBox = await FirebaseFirestore.instance.collection('idboxes').where('sindico_vinculado', isEqualTo: widget.emailSindico).get(), snapCam = await FirebaseFirestore.instance.collection('cameras').where('sindico_vinculado', isEqualTo: widget.emailSindico).get();
    if (mounted) setState(() { _dispositivosiDBox = snapBox.docs; _camerasDisponiveis = snapCam.docs; });
  }

  void _mostrarModalPortao({DocumentSnapshot? doc}) {
    final isEdit = doc != null, data = isEdit ? doc.data() as Map<String, dynamic> : {};
    String ipCamera = data['ip_camera'] ?? "", idBoxSelecionada = data['id_box'] ?? "";
    
    final nomeCtrl = TextEditingController(text: data['nome'] ?? "");
    final codigoCtrl = TextEditingController(text: data['codigo'] ?? "");
    final tempoCtrl = TextEditingController(text: (data['tempo_abertura'] ?? 15).toString());

    if (ipCamera.isNotEmpty && !_camerasDisponiveis.any((c) => c.id == ipCamera)) ipCamera = "";
    
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: FittedBox(fit: BoxFit.scaleDown, child: Text(isEdit ? "Editar Portão" : "Configurar Novo Portão")),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children:[
          TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: "Nome (ex: Portão Principal)")), const SizedBox(height: 10),
          TextField(controller: codigoCtrl, decoration: const InputDecoration(labelText: "Código de Abertura / Relé (ex: 1 ou 2)")), const SizedBox(height: 10),
          TextField(controller: tempoCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Tempo de Percurso do Motor (Segundos)", helperText: "Bloqueia cliques duplos enquanto o portão se move.", filled: true, fillColor: Colors.orange.withValues(alpha:0.1))), const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft, child: Text("Câmera Vinculada (Opcional):", style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(height: 5),
          DropdownButtonFormField<String>(isExpanded: true, decoration: const InputDecoration(border: OutlineInputBorder()), hint: const Text("Nenhuma Câmera"), initialValue: ipCamera.isEmpty ? null : ipCamera, items: [const DropdownMenuItem(value: "", child: Text("Nenhuma (Apenas Botão)")), ..._camerasDisponiveis.map((c) => DropdownMenuItem(value: c.id, child: Text((c.data() as Map<String, dynamic>)['nome'] ?? 'Câmera')))], onChanged: (v) => setStateSB(() => ipCamera = v!)), const SizedBox(height: 20),
          const Align(alignment: Alignment.centerLeft, child: Text("Vincular Módulo iDBox (Control iD):", style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(height: 5),
          DropdownButtonFormField<String>(isExpanded: true, decoration: const InputDecoration(border: OutlineInputBorder()), hint: const Text("Selecione o Dispositivo"), initialValue: idBoxSelecionada.isEmpty ? null : idBoxSelecionada, items: _dispositivosiDBox.map((d) { final m = d.data() as Map<String, dynamic>; return DropdownMenuItem(value: m['id_unico'] as String, child: Text("${m['nome']} (${m['id_unico']})")); }).toList(), onChanged: (v) => setStateSB(() => idBoxSelecionada = v!))
        ])),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async {
            if (nomeCtrl.text.trim().isNotEmpty && codigoCtrl.text.trim().isNotEmpty && idBoxSelecionada.isNotEmpty) {
              final updateData = {'sindico_vinculado': widget.emailSindico, 'nome': nomeCtrl.text.trim(), 'codigo': codigoCtrl.text.trim(), 'ip_camera': ipCamera, 'id_box': idBoxSelecionada, 'tempo_abertura': int.tryParse(tempoCtrl.text.trim()) ?? 15, 'permite_morador': isEdit ? (data['permite_morador'] ?? false) : false};
              if (isEdit) await doc.reference.update(updateData); else await FirebaseFirestore.instance.collection('portoes').add(updateData);
              if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? "Portão atualizado!" : "Portão criado!"), backgroundColor: Colors.green)); }
            } else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Preencha Nome, Relé e selecione uma iDBox!", style: TextStyle(color: colorScheme.onError)), backgroundColor: colorScheme.error));
          }, child: const Text("SALVAR"))
        ],
      );
    }));
  }

  void _abrirPortao(Map<String, dynamic> dataPortao, String idPortao, String idBox) async {
    final nome = dataPortao['nome'], rele = dataPortao['codigo'], tempoAbertura = dataPortao['tempo_abertura'] ?? 15;
    if (GerenciadorDeTunel.isReleEmMovimento(rele, tempoAbertura)) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text("Aguarde! Portão já está em movimento.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))); return; }
    try {
      final docAtual = await FirebaseFirestore.instance.collection('portoes').doc(idPortao).get(const GetOptions(source: Source.server)).timeout(const Duration(milliseconds: 800));
      if (docAtual.exists && docAtual.data()!['ultima_abertura'] != null && DateTime.now().difference((docAtual.data()!['ultima_abertura'] as Timestamp).toDate()).inSeconds.abs() < tempoAbertura) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text("Aguarde! Portão já está em movimento.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))); return; }
    } catch(_) {}
    FirebaseFirestore.instance.collection('portoes').doc(idPortao).update({'ultima_abertura': FieldValue.serverTimestamp()}).then((_) {}, onError: (_) {});
    GerenciadorDeTunel.registrarMovimentoRele(rele);

    mostrarBrilhoNeon(context); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aguarde..."), duration: Duration(seconds: 1)));

    bool sucessoLocal = false;
    try {
      final placaDoc = _dispositivosiDBox.firstWhere((d) => (d.data() as Map)['id_unico'] == idBox, orElse: () => throw Exception("Placa não encontrada.")), dataPlaca = placaDoc.data() as Map<String, dynamic>, ipLocal = dataPlaca['ip_local'] ?? '';
      if (ipLocal.isNotEmpty) {
        final responseLogin = await http.post(Uri.parse('http://$ipLocal/login.fcgi'), headers: {'Content-Type': 'application/json', 'Connection': 'close'}, body: jsonEncode({"login": dataPlaca['usuario'] ?? 'admin', "password": dataPlaca['senha_criptografada']?.isNotEmpty == true ? CryptoHelper.descriptografar(dataPlaca['senha_criptografada']) : ''})).timeout(const Duration(milliseconds: 2500));
        if (responseLogin.statusCode == 200 && (await http.post(Uri.parse('http://$ipLocal/execute_actions.fcgi?session=${jsonDecode(responseLogin.body)['session']}'), headers: {'Content-Type': 'application/json', 'Connection': 'close'}, body: jsonEncode({"actions": [{"action": "sec_box", "parameters": "id=$rele, reason=3"}, {"action": "door", "parameters": "door=$rele"}]})).timeout(const Duration(milliseconds: 2500))).statusCode == 200) {
          sucessoLocal = true; registrarAuditoria(widget.emailSindico, "Abertura de Portão (Rede Local)", "Controle de Acessos", "Portão $nome acionado.").catchError((_) => null);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Portão abrindo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
        }
      }
    } catch (_) {}

    if (!sucessoLocal) {
      try {
        final token = FirebaseAuth.instance.currentUser != null ? await FirebaseAuth.instance.currentUser!.getIdToken() : '';
        if ((await http.post(Uri.parse('https://us-central1-logichome-a9808.cloudfunctions.net/solicitarAberturaPortao'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({'data': {'id_dispositivo': idBox, 'id_portao': idPortao, 'rele': rele, 'operador': operadorLogado}}))).statusCode == 200) {
          registrarAuditoria(widget.emailSindico, "Abertura de Portão (Nuvem Fallback)", "Controle de Acessos", "Portão $nome acionado via 4G.").catchError((_) => null);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Portão abrindo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
        } else throw Exception("Falha na nuvem.");
      } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Falha ao comunicar com o portão.", style: TextStyle(color: Colors.white)))); }
    }
  }

// [FIM DO BLOCO - DIGITE "CONTINUE" PARA GERAR A PRÓXIMA PARTE]
@override
  Widget build(BuildContext context) {
    final isTecnico = widget.perfil == 'tecnico', colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: isTecnico ? FloatingActionButton.extended(onPressed: () => _mostrarModalPortao(), icon: const Icon(Icons.add), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("Adicionar Portão"))) : null,
      body: Column(children:[
        Padding(padding: const EdgeInsets.all(16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Controle de Portões", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)))), IconButton(icon: const Icon(Icons.refresh), tooltip: "Recarregar Portões", onPressed: () => setState(() {}))])),
        Expanded(
          key: keyTutPorCentro,
          child: StreamBuilder<QuerySnapshot>(
            stream: _portoesStream,
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text("Erro ao carregar portões."));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhum portão configurado no momento."));
              final isDesktopOrWeb = kIsWeb || defaultTargetPlatform == TargetPlatform.windows;

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 450, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.9),
                itemCount: snap.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snap.data!.docs[index], data = doc.data() as Map<String, dynamic>, idCameraVinculada = data['ip_camera'] ?? "", idBox = data['id_box'] ?? "";
                  Widget playerWidget = const Center(child: Icon(Icons.videocam_off, color: Colors.white54, size: 50));

                  if (idCameraVinculada.isNotEmpty) {
                    final camDocsFiltro = _camerasDisponiveis.where((c) => c.id == idCameraVinculada);
                    final camDoc = camDocsFiltro.isNotEmpty ? camDocsFiltro.first : null;
                    
                    if (camDoc != null) {
                      final camData = camDoc.data() as Map<String, dynamic>;
                      String senhaPlayer = camData['senha'] ?? '';
                      if (camData['senha_criptografada'] == true) senhaPlayer = CryptoHelper.descriptografar(senhaPlayer);
                      else if (camData['senha_ofuscada'] == true) try { senhaPlayer = utf8.decode(base64Decode(senhaPlayer)); } catch (_) {}
                      playerWidget = SmartCameraPlayer(nomeCamera: camData['nome'] ?? 'Câmera do Portão', cameraId: camDoc.id, sindicoVinculado: widget.emailSindico, ipLocal: camData['ip'] ?? '', portaRtsp: camData['porta_rtsp'] ?? '554', usuario: camData['usuario'] ?? 'admin', senha: senhaPlayer, canal: camData['canal'] ?? '1');
                    } else playerWidget = const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text("Câmera desvinculada. Clique em Editar e selecione a câmera na lista.", textAlign: TextAlign.center, style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))));
                  }

                  return Card(
                    elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children:[
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[
                        Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'].toString().toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                        if (isTecnico) ...[IconButton(icon: Icon(Icons.edit, color: colorScheme.primary, size: 20), onPressed: () => _mostrarModalPortao(doc: doc), padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: "Editar Portão"), const SizedBox(width: 10), IconButton(icon: Icon(Icons.delete, color: colorScheme.error, size: 20), onPressed: () async { await doc.reference.delete(); }, padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: "Remover Portão")]
                      ])),
                      AspectRatio(aspectRatio: 16 / 9, child: Container(clipBehavior: Clip.antiAlias, decoration: const BoxDecoration(color: Colors.black), child: Stack(fit: StackFit.expand, children:[playerWidget, if (idCameraVinculada.isNotEmpty) Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), color: Colors.black54, child: const Text("VINCULADA AO PORTÃO", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))))]))), 
                      Expanded(child: Padding(padding: const EdgeInsets.all(16.0), child: Center(child: isDesktopOrWeb ? LogicNeonButton(fullWidth: true, corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: () => _abrirPortao(data, doc.id, idBox), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_open, color: Colors.white, size: 18), SizedBox(width: 10), Text("CLIQUE PARA ABRIR", style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 2))])) : SliderAbrirPortao(nomePortao: data['nome'], onSlid: () => _abrirPortao(data, doc.id, idBox)))))
                    ]),
                  );
                },
              );
            }
          ),
        )
      ])
    );
  }
}

class PlayerCameraReal extends StatefulWidget {
  final String url;
  final bool isPortao;
  const PlayerCameraReal({super.key, required this.url, this.isPortao = false});
  @override
  State<PlayerCameraReal> createState() => _PlayerCameraRealState();
}

class _PlayerCameraRealState extends State<PlayerCameraReal> {
  Player? _player; VideoController? _controller;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // Reduz o buffer do player para 1MB, forçando carregamento quase instantâneo na rede local
      _player = Player(configuration: const PlayerConfiguration(bufferSize: 1024 * 1024));
      _player!.open(Media(widget.url));
      _player!.play();
      _controller = VideoController(_player!);
    }
  }
  @override
  void dispose() { if (!kIsWeb) _player?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return Container(color: Colors.black, child: const Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text("Visualização não suportada na Web.\nUse o App Mobile ou Desktop (Windows).", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12)))));
    return AspectRatio(aspectRatio: 16 / 9, child: _controller != null ? Video(controller: _controller!) : const Center(child: CircularProgressIndicator()));
  }
}

class PlayerIntelbras extends StatefulWidget {
  final String ip, portaRtsp, usuario, senha, canal, nomeCamera;
  final bool altaQualidade;
  final VoidCallback? onEdit, onDelete;
  const PlayerIntelbras({super.key, required this.ip, this.portaRtsp = '554', this.usuario = 'admin', required this.senha, this.canal = '1', required this.nomeCamera, this.altaQualidade = false, this.onEdit, this.onDelete});
  @override
  State<PlayerIntelbras> createState() => _PlayerIntelbrasState();
}

class _PlayerIntelbrasState extends State<PlayerIntelbras> {
  Player? _player; VideoController? _videoController;
  bool _isInitializing = true, _hasError = false, _isDisposed = false;
  Timer? _watchdogTimer; Duration _ultimaPosicao = Duration.zero;

  @override
  void initState() { super.initState(); if (!kIsWeb) _inicializarCamera(); }

  void _inicializarCamera() {
    if (_isDisposed) return;
    try {
      final url = 'rtsp://${Uri.encodeComponent(widget.usuario)}:${Uri.encodeComponent(widget.senha)}@${widget.ip}:${widget.portaRtsp}/cam/realmonitor?channel=${widget.canal}&subtype=${widget.altaQualidade ? '0' : '1'}';
      // Reduz o buffer do player para 1MB, cortando o delay artificial de carregamento RTSP
      _player = Player(configuration: const PlayerConfiguration(bufferSize: 1024 * 1024)); 
      _videoController = VideoController(_player!);
      _player!.stream.error.listen((_) { if (mounted && !_isDisposed) _engatilharReconexao("Erro de Rede"); });
      _player!.stream.playing.listen((isPlaying) { if (mounted && _isInitializing && isPlaying) { setState(() { _isInitializing = false; _hasError = false; }); _iniciarWatchdogAntiCongelamento(); } });
      _player!.open(Media(url)); Future.delayed(const Duration(milliseconds: 100), () { if (mounted && _player != null && !_isDisposed) _player!.play(); });
    } catch (_) { _engatilharReconexao("Falha na Abertura"); }
  }

  void _iniciarWatchdogAntiCongelamento() {
    _watchdogTimer?.cancel(); _ultimaPosicao = Duration.zero;
    _watchdogTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (_isDisposed || _player == null) { timer.cancel(); return; }
      final pos = _player!.state.position;
      if (pos == _ultimaPosicao && pos > Duration.zero) { timer.cancel(); _engatilharReconexao("Imagem Congelada"); } else _ultimaPosicao = pos;
    });
  }

  void _engatilharReconexao(String motivo) {
    if (_isDisposed) return; _watchdogTimer?.cancel();
    if (mounted) setState(() { _hasError = true; _isInitializing = true; });
    _player?.dispose(); _player = null; _videoController = null;
    Future.delayed(const Duration(seconds: 4), () { if (mounted && !_isDisposed) _inicializarCamera(); });
  }

  Future<void> _abrirAppIntelbrasMobile() async { if (await canLaunchUrl(Uri.parse("isiclite://"))) await launchUrl(Uri.parse("isiclite://")); else await launchUrl(Uri.parse("https://play.google.com/store/apps/details?id=com.intelbras.isiclite"), mode: LaunchMode.externalApplication); }
  Future<void> _abrirInterfaceWeb() async { final url = Uri.parse('http://${widget.ip}'); if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication); else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não foi possível abrir o navegador. Verifique o IP."))); }

  @override
  void dispose() { _isDisposed = true; _watchdogTimer?.cancel(); if (!kIsWeb) _player?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return Container(color: Colors.black, child: const Center(child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.videocam_off, color: Colors.white54, size: 40), SizedBox(height: 10), Text("Visualização RTSP indisponível na Web.\nAbra o App Mobile ou App Windows para ver as câmeras.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 12))]))));
    final isMobile = (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    return Card(color: Colors.black, clipBehavior: Clip.antiAlias, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: AspectRatio(aspectRatio: 16 / 9, child: Stack(fit: StackFit.expand, children:[
      if (!_hasError && _videoController != null && !_isInitializing) Video(controller: _videoController!, controls: NoVideoControls),
      if (_hasError || _isInitializing) Center(child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[if (_hasError) const Icon(Icons.wifi_off, color: Colors.orange, size: 40) else const CircularProgressIndicator(color: Colors.blue), const SizedBox(height: 10), Text(_hasError ? "Sinal Perdido. Reconectando..." : "Conectando Câmera Local...", style: const TextStyle(color: Colors.white, fontSize: 12))]))),
      if (isMobile && !widget.altaQualidade) Positioned(top: 10, left: 10, child: FittedBox(fit: BoxFit.scaleDown, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white), icon: const Icon(Icons.phone_android, size: 16), label: const Text("Abrir App Intelbras", style: TextStyle(fontSize: 10)), onPressed: _abrirAppIntelbrasMobile))),
      if (!widget.altaQualidade) Positioned(top: 0, right: 0, child: Container(decoration: BoxDecoration(color: Colors.black.withValues(alpha:0.6), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10))), child: Row(mainAxisSize: MainAxisSize.min, children:[IconButton(icon: const Icon(Icons.language, color: Colors.white, size: 18), tooltip: "Acessar via Web (DVR)", onPressed: _abrirInterfaceWeb, padding: const EdgeInsets.all(8), constraints: const BoxConstraints()), if (widget.onEdit != null) IconButton(icon: const Icon(Icons.settings, color: Colors.blue, size: 18), tooltip: "Configurar Câmera", onPressed: widget.onEdit, padding: const EdgeInsets.all(8), constraints: const BoxConstraints()), if (widget.onDelete != null) IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), tooltip: "Excluir Câmera", onPressed: widget.onDelete, padding: const EdgeInsets.all(8), constraints: const BoxConstraints())]))),
      Positioned(bottom: 0, left: 0, right: 0, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors:[Colors.black87, Colors.transparent])), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Row(children:[Icon(Icons.fiber_manual_record, color: _hasError ? Colors.grey : Colors.red, size: 12), const SizedBox(width: 8), Expanded(child: Text(widget.nomeCamera, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))), if (!widget.altaQualidade) IconButton(icon: const Icon(Icons.fullscreen, color: Colors.white, size: 24), tooltip: "Tela Cheia / Controles PTZ", padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelaCameraCheia(nomeCamera: widget.nomeCamera, ip: widget.ip, portaRtsp: widget.portaRtsp, usuario: widget.usuario, senha: widget.senha, canal: widget.canal))))])))
    ])));
  }
}

class TelaCameraCheia extends StatefulWidget {
  final String nomeCamera, ip, portaRtsp, usuario, senha, canal;
  const TelaCameraCheia({super.key, required this.nomeCamera, required this.ip, required this.portaRtsp, required this.usuario, required this.senha, required this.canal});
  @override
  State<TelaCameraCheia> createState() => _TelaCameraCheiaState();
}

class _TelaCameraCheiaState extends State<TelaCameraCheia> {
  Future<void> _enviarComandoPTZ(String comando, String acao) async { try { await http.get(Uri.parse('http://${widget.ip}/cgi-bin/ptz.cgi?action=$acao&channel=${widget.canal}&code=$comando&arg1=5&arg2=5&arg3=0'), headers: {'Authorization': 'Basic ${base64Encode(utf8.encode('${widget.usuario}:${widget.senha}'))}'}).timeout(const Duration(seconds: 3)); } catch(_) {} }
  Widget _botaoPTZ(IconData icone, String cmd) => GestureDetector(onTapDown: (_) => _enviarComandoPTZ(cmd, "start"), onTapUp: (_) => _enviarComandoPTZ(cmd, "stop"), onTapCancel: () => _enviarComandoPTZ(cmd, "stop"), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white30)), child: Icon(icone, color: Colors.white, size: 30)));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: FittedBox(fit: BoxFit.scaleDown, child: Text("${widget.nomeCamera} (Alta Qualidade)"))),
    body: Stack(children:[
      Center(child: AspectRatio(aspectRatio: 16 / 9, child: PlayerIntelbras(nomeCamera: widget.nomeCamera, ip: widget.ip, portaRtsp: widget.portaRtsp, usuario: widget.usuario, senha: widget.senha, canal: widget.canal, altaQualidade: true))),
      if (defaultTargetPlatform == TargetPlatform.windows) Positioned(bottom: 40, right: 40, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.withValues(alpha:0.5))), child: Column(children:[const Text("Controle PTZ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.center, children:[_botaoPTZ(Icons.zoom_out, "ZoomWide"), const SizedBox(width: 10), _botaoPTZ(Icons.arrow_upward, "Up"), const SizedBox(width: 10), _botaoPTZ(Icons.zoom_in, "ZoomTele")]), const SizedBox(height: 10), Row(mainAxisAlignment: MainAxisAlignment.center, children:[_botaoPTZ(Icons.arrow_back, "Left"), const SizedBox(width: 10), _botaoPTZ(Icons.arrow_downward, "Down"), const SizedBox(width: 10), _botaoPTZ(Icons.arrow_forward, "Right")])])))
    ]),
  );
}

class TelaCameras extends StatefulWidget {
  final String emailSindico, perfil;
  const TelaCameras({super.key, required this.emailSindico, required this.perfil});
  @override
  State<TelaCameras> createState() => _TelaCamerasState();
}

class _TelaCamerasState extends State<TelaCameras> {
  late Stream<QuerySnapshot> _camerasStream;
  @override
  void initState() { super.initState(); _camerasStream = FirebaseFirestore.instance.collection('cameras').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots(); }

  void _mostrarModalCamera({DocumentSnapshot? doc}) {
    final isEdit = doc != null, data = isEdit ? doc.data() as Map<String, dynamic> : {};
    String senhaSalva = data['senha'] ?? ''; if (data['senha_criptografada'] == true) senhaSalva = CryptoHelper.descriptografar(senhaSalva); else if (data['senha_ofuscada'] == true) try { senhaSalva = utf8.decode(base64Decode(senhaSalva)); } catch (_) {}
    final nomeCtrl = TextEditingController(text: data['nome'] ?? ''), ipCtrl = TextEditingController(text: data['ip'] ?? ''), usuarioCtrl = TextEditingController(text: data['usuario'] ?? 'admin'), senhaCtrl = TextEditingController(text: senhaSalva), canalCtrl = TextEditingController(text: data['canal'] ?? '1'), portaCtrl = TextEditingController(text: data['porta_rtsp'] ?? '554');
    bool ocultarSenha = true;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: FittedBox(fit: BoxFit.scaleDown, child: Text(isEdit ? "Configurações da Câmera" : "Vincular Câmera Intelbras / DVR")),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children:[TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: "Nome da Câmera (ex: Portão Principal)")), const SizedBox(height: 10), TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: "IP ou DynDNS (ex: 192.168.1.108)")), const SizedBox(height: 10), Row(children:[Expanded(child: TextField(controller: usuarioCtrl, decoration: const InputDecoration(labelText: "Usuário"))), const SizedBox(width: 10), Expanded(child: TextField(controller: senhaCtrl, obscureText: ocultarSenha, decoration: InputDecoration(labelText: "Senha", suffixIcon: IconButton(icon: Icon(ocultarSenha ? Icons.visibility_off : Icons.visibility), onPressed: () => setStateSB(() => ocultarSenha = !ocultarSenha))))) ]), const SizedBox(height: 10), Row(children:[Expanded(child: TextField(controller: canalCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Canal do DVR (ex: 1)"))), const SizedBox(width: 10), Expanded(child: TextField(controller: portaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Porta RTSP (Padrão: 554)")))])]))),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async {
            if (nomeCtrl.text.isNotEmpty && ipCtrl.text.isNotEmpty && senhaCtrl.text.isNotEmpty) {
              final dadosCamera = {'sindico_vinculado': widget.emailSindico, 'nome': nomeCtrl.text.trim(), 'ip': ipCtrl.text.trim(), 'usuario': usuarioCtrl.text.trim(), 'senha': CryptoHelper.criptografar(senhaCtrl.text.trim()), 'senha_criptografada': true, 'canal': canalCtrl.text.trim(), 'porta_rtsp': portaCtrl.text.trim(), 'marca': 'intelbras', 'visivel_morador': isEdit ? (data['visivel_morador'] ?? false) : false};
              if (isEdit) { await doc.reference.update(dadosCamera); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Configurações atualizadas com sucesso!"))); } else { await FirebaseFirestore.instance.collection('cameras').add(dadosCamera); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Câmera vinculada com sucesso!"))); }
              if (mounted) Navigator.pop(ctx);
            } else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Preencha Nome, IP e Senha!"), backgroundColor: colorScheme.error));
          }, child: Text(isEdit ? "SALVAR ALTERAÇÕES" : "VINCULAR CÂMERA"))
        ],
      );
    }));
  }

  void _confirmarExclusao(DocumentReference ref) {
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: Text("Excluir Câmera", style: TextStyle(color: colorScheme.error)), content: const Text("Tem certeza que deseja remover esta câmera do painel?"), actions:[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError), onPressed: () async { await ref.delete(); if (mounted) Navigator.pop(ctx); }, child: const Text("EXCLUIR"))]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTecnico = widget.perfil == 'tecnico';
    return Scaffold(
      floatingActionButton: isTecnico ? FloatingActionButton.extended(onPressed: () => _mostrarModalCamera(), icon: const Icon(Icons.add_a_photo), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("Nova Câmera"))) : null,
      body: Column(children:[
        const Padding(padding: EdgeInsets.all(16.0), child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: Text("Monitoramento de Câmeras", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))))),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: _camerasStream, builder: (context, snap) {
          if (snap.hasError) return const Center(child: Text("Erro ao carregar câmeras."));
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text("Nenhuma câmera vinculada.", style: TextStyle(fontSize: 16, color: Colors.grey)));
          return GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 400, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 16 / 9), itemCount: snap.data!.docs.length, itemBuilder: (context, index) {
            final doc = snap.data!.docs[index], data = doc.data() as Map<String, dynamic>;
            String senhaPlayer = data['senha'] ?? ''; if (data['senha_criptografada'] == true) senhaPlayer = CryptoHelper.descriptografar(senhaPlayer); else if (data['senha_ofuscada'] == true) try { senhaPlayer = utf8.decode(base64Decode(senhaPlayer)); } catch (_) {}
            return SmartCameraPlayer(nomeCamera: data['nome'] ?? 'Câmera', cameraId: doc.id, sindicoVinculado: widget.emailSindico, ipLocal: data['ip'] ?? '', portaRtsp: data['porta_rtsp'] ?? '554', usuario: data['usuario'] ?? 'admin', senha: senhaPlayer, canal: data['canal'] ?? '1', onEdit: isTecnico ? () => _mostrarModalCamera(doc: doc) : null, onDelete: isTecnico ? () => _confirmarExclusao(doc.reference) : null);
          });
        }))
      ])
    );
  }
}

class TelaEncomendas extends StatefulWidget {
  final String emailSindico;
  const TelaEncomendas({super.key, required this.emailSindico});
  @override
  State<TelaEncomendas> createState() => _TelaEncomendasState();
}

class _TelaEncomendasState extends State<TelaEncomendas> {
  void _registrarLote() => showDialog(context: context, barrierDismissible: false, builder: (ctx) => DialogRecebimentoLote(emailSindico: widget.emailSindico));
  void _iniciarRetirada() {
    String codigoDigitado = "";
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Retirar Encomenda")), content: Column(mainAxisSize: MainAxisSize.min, children:[const Text("Peça ao morador o código (PIN) gerado no aplicativo dele.", style: TextStyle(color: Colors.grey)), const SizedBox(height: 15), TextField(onChanged: (v) => codigoDigitado = v.trim(), decoration: const InputDecoration(labelText: "PIN Numérico", border: OutlineInputBorder()), keyboardType: TextInputType.number, style: const TextStyle(fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold), textAlign: TextAlign.center)]), actions:[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async {
        if (codigoDigitado.isEmpty) return;
        final snap = await FirebaseFirestore.instance.collection('encomendas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('codigos_acesso', arrayContains: codigoDigitado).where('status', isEqualTo: 'aguardando').get();
        if (!mounted) return; Navigator.pop(ctx);
        if (snap.docs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Nenhum pacote aguardando com este PIN.", style: TextStyle(color: colorScheme.onError)), backgroundColor: colorScheme.error)); return; }
        _abrirSessaoDeBipagem(codigoDigitado);
      }, child: const Text("PROSSEGUIR"))]);
    });
  }

  void _abrirSessaoDeBipagem(String codigoRetirada) {
    final leitorOutCtrl = TextEditingController(), isDesktopOrWeb = kIsWeb || defaultTargetPlatform == TargetPlatform.windows;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('encomendas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('codigos_acesso', arrayContains: codigoRetirada).where('status', whereIn:['aguardando', 'em_retirada', 'confirmado_morador']).snapshots(), builder: (context, snapshot) {
      final colorScheme = Theme.of(context).colorScheme;
      if (!snapshot.hasData) return const AlertDialog(content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())));
      final docs = snapshot.data!.docs; if (docs.isEmpty) return AlertDialog(content: const Text("Todos os pacotes foram entregues! Feche esta janela."), actions:[TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("FECHAR"))]);
      String statusAtual = 'aguardando'; if (docs.every((d) => (d.data() as Map)['status'] == 'confirmado_morador')) statusAtual = 'confirmado_morador'; else if (docs.every((d) => (d.data() as Map)['status'] == 'em_retirada')) statusAtual = 'em_retirada';
      List<String> codigosEsperados =[], codigosBipados =[]; final bloco = (docs.first.data() as Map)['bloco'], ap = (docs.first.data() as Map)['ap'];
      for (var d in docs) { final dataMap = d.data() as Map<String, dynamic>; codigosEsperados.addAll(List<String>.from(dataMap['codigos_barras'] ??[])); codigosBipados.addAll(List<String>.from(dataMap['codigos_bipados'] ??[])); }

      void verificarCodigo(String cod) {
        final c = cod.trim(); if (c.isEmpty) return;
        final docsEncontrados = docs.where((d) => ((d.data() as Map)['codigos_barras'] as List).contains(c));
        final docMatch = docsEncontrados.isNotEmpty ? docsEncontrados.first : null;
        if (docMatch != null) {
          final bipadosAtuais = (docMatch.data() as Map)['codigos_bipados'] ?? [];
          if (!bipadosAtuais.contains(c)) docMatch.reference.update({'codigos_bipados': FieldValue.arrayUnion([c])}); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pacote já foi bipado agora!")));
        } else ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ESTE PACOTE NÃO PERTENCE A ESSE CÓDIGO PIN", style: TextStyle(color: colorScheme.onError, fontWeight: FontWeight.bold)), backgroundColor: colorScheme.error, duration: const Duration(seconds: 3)));
        leitorOutCtrl.clear();
      }

      return AlertDialog(
        title: Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children:[Icon(Icons.handshake, color: colorScheme.primary), FittedBox(fit: BoxFit.scaleDown, child: Text("Mesa de Retirada: Bloco $bloco / AP $ap"))]),
        content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text("Total no apartamento: ${codigosEsperados.length} pacote(s)", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const Divider(height: 30),
          if (statusAtual == 'aguardando') ...[
            const Text("Pegue os pacotes desse AP na prateleira e escaneie aleatoriamente:", style: TextStyle(color: Colors.grey)), const SizedBox(height: 15),
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children:[SizedBox(width: 250, child: TextField(controller: leitorOutCtrl, decoration: InputDecoration(labelText: isDesktopOrWeb ? "Bipar Pacote (Leitor USB)" : "Digitar / Escanear Código", border: const OutlineInputBorder()), onSubmitted: verificarCodigo, autofocus: isDesktopOrWeb)), if (!isDesktopOrWeb) IconButton(icon: Icon(Icons.qr_code_scanner, color: colorScheme.primary, size: 40), tooltip: "Escanear com a Câmera", onPressed: () async { final barcodeScanRes = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const TelaScanner())); if (barcodeScanRes != null && barcodeScanRes.isNotEmpty) verificarCodigo(barcodeScanRes); })]), const SizedBox(height: 20),
            Container(height: 150, decoration: BoxDecoration(border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(5)), child: ListView.builder(itemCount: codigosEsperados.length, itemBuilder: (c, i) { final codigo = codigosEsperados[i], isBipado = codigosBipados.contains(codigo); return ListTile(leading: Icon(isBipado ? Icons.check_circle : Icons.radio_button_unchecked, color: isBipado ? Colors.green : Colors.grey), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(codigo, style: TextStyle(decoration: isBipado ? TextDecoration.lineThrough : null, color: isBipado ? Colors.grey : colorScheme.onSurface))), trailing: isBipado ? const Text("MESA", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)) : const Text("PRATELEIRA")); })), const SizedBox(height: 20),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: codigosBipados.isNotEmpty ? colorScheme.secondary : Colors.grey, foregroundColor: codigosBipados.isNotEmpty ? colorScheme.onSecondary : Colors.white, minimumSize: const Size(double.infinity, 50)), icon: const Icon(Icons.done_all), label: FittedBox(fit: BoxFit.scaleDown, child: Text("FINALIZAR BIPAGEM (${codigosBipados.length}/${codigosEsperados.length})")), onPressed: codigosBipados.isEmpty ? null : () { final batch = FirebaseFirestore.instance.batch(); for (var d in docs) batch.update(d.reference, {'status': 'em_retirada'}); batch.commit(); })
          ],
          if (statusAtual == 'em_retirada') ...[Center(child: Column(children:[CircularProgressIndicator(color: colorScheme.secondary), const SizedBox(height: 20), Text("Aguardando confirmação do morador...\nEle deve abrir o aplicativo para assinar a retirada de ${codigosBipados.length} pacote(s).", style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center)]))],
          if (statusAtual == 'confirmado_morador') ...[Center(child: Column(children:[const Icon(Icons.check_circle, color: Colors.green, size: 60), const SizedBox(height: 10), const Text("Morador Confirmou!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20)), const SizedBox(height: 5), Text("Retirada assinada por: ${(docs.first.data() as Map)['quem_retirou'] ?? 'Morador'}", style: const TextStyle(color: Colors.grey, fontSize: 14)), const SizedBox(height: 20), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50)), icon: const Icon(Icons.check), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("CONCLUIR ENTREGA")), onPressed: () async { final batch = FirebaseFirestore.instance.batch(); for(var d in docs) batch.update(d.reference, {'status': 'entregue', 'data_entrega': FieldValue.serverTimestamp(), 'operador_entrega': operadorLogado}); await batch.commit(); await registrarAuditoria(widget.emailSindico, "Entrega de Encomendas", "Encomendas", "Bloco $bloco AP $ap (PIN: $codigoRetirada). Retirado por: ${(docs.first.data() as Map)['quem_retirou']}."); if (!mounted) return; Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entrega finalizada com sucesso!"))); })]))]
        ])),
        actions:[if (statusAtual != 'confirmado_morador') TextButton(onPressed: () { final batch = FirebaseFirestore.instance.batch(); for(var d in docs) batch.update(d.reference, {'status': 'aguardando'}); batch.commit(); Navigator.pop(ctx); }, child: Text("CANCELAR E VOLTAR", style: TextStyle(color: colorScheme.error)))]
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(child: SingleChildScrollView(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[
      Icon(Icons.local_shipping, size: 100, color: colorScheme.primary), const SizedBox(height: 30), const FittedBox(fit: BoxFit.scaleDown, child: Text("Central de Encomendas", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))), const SizedBox(height: 40),
      Wrap(spacing: 20, runSpacing: 20, alignment: WrapAlignment.center, children:[
        SizedBox(width: 250, height: 200, child: LogicNeonButton(key: keyTutEncReceber, onPressed: _registrarLote, corBase: colorScheme.primary, corBrilho: colorScheme.primary, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.add_box, size: 50, color: Colors.white), SizedBox(height: 15), Text("Receber Encomenda", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]))),
        SizedBox(width: 250, height: 200, child: LogicNeonButton(key: keyTutEncRetirar, onPressed: _iniciarRetirada, corBase: colorScheme.secondary, corBrilho: colorScheme.secondary, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.outbox, size: 50, color: Colors.white), SizedBox(height: 15), Text("Retirada de Encomenda", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]))),
      ])
    ])));
  }
}

class DialogRecebimentoLote extends StatefulWidget {
  final String emailSindico;
  const DialogRecebimentoLote({super.key, required this.emailSindico});
  @override
  State<DialogRecebimentoLote> createState() => _DialogRecebimentoLoteState();
}

class _DialogRecebimentoLoteState extends State<DialogRecebimentoLote> {
  int _estadoAtual = 0;
  final _entregadorCtrl = TextEditingController(), _empresaCtrl = TextEditingController(), _qtdCtrl = TextEditingController(), _codigoManualCtrl = TextEditingController(), _nomeCtrl = TextEditingController(), _blocoCtrl = TextEditingController(), _apCtrl = TextEditingController();
  String _codigoTemporarioLido = "";
  final List<Map<String, dynamic>> _pacotes = [];

  @override
  void dispose() { _entregadorCtrl.dispose(); _empresaCtrl.dispose(); _qtdCtrl.dispose(); _nomeCtrl.dispose(); _blocoCtrl.dispose(); _apCtrl.dispose(); _codigoManualCtrl.dispose(); super.dispose(); }

  void _iniciarSessao() {
    if (_entregadorCtrl.text.trim().isEmpty || _empresaCtrl.text.trim().isEmpty || _qtdCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os dados da remessa."))); return; }
    setState(() => _estadoAtual = 1);
  }

  void _processarCodigoLido(String codigo) async {
    final codeTratado = codigo.trim(); if (codeTratado.isEmpty) return;
    if (_pacotes.any((p) => p['codigo'] == codeTratado)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Este código já foi lido neste lote!"))); return; }
    final snapExistenteNoBanco = await FirebaseFirestore.instance.collection('encomendas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('codigos_barras', arrayContains: codeTratado).get();
    if (!mounted) return;
    if (snapExistenteNoBanco.docs.isNotEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Essa encomenda já existe no banco de dados!", style: TextStyle(color: Theme.of(context).colorScheme.onError)), backgroundColor: Theme.of(context).colorScheme.error)); return; }
    setState(() { _codigoTemporarioLido = codeTratado; _codigoManualCtrl.clear(); _estadoAtual = 2; });
  }

  void _iniciarEscaneamentoMobile() async { final res = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const TelaScanner())); if (res != null && res.isNotEmpty) _processarCodigoLido(res); }

  Future<void> _imprimirEtiqueta(String bloco, String ap, String nome, String codRastreio) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.roll80, build: (context) => pw.Container(padding: const pw.EdgeInsets.all(10), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, mainAxisSize: pw.MainAxisSize.min, children: [pw.Text("B: $bloco", style: pw.TextStyle(fontSize: 45, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 5), pw.Text("AP: $ap", style: pw.TextStyle(fontSize: 45, fontWeight: pw.FontWeight.bold)), pw.Divider(thickness: 2), pw.Text(nome.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center), pw.SizedBox(height: 10), pw.Text("Rastreio:", style: const pw.TextStyle(fontSize: 10)), pw.Text(codRastreio, style: const pw.TextStyle(fontSize: 12))]))));
    try { await Printing.layoutPdf(onLayout: (format) async => doc.save(), name: 'Etiqueta_${bloco}_$ap'); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro na impressora: $e"))); }
  }

  Future<void> _salvarPacoteLido() async {
    if (_nomeCtrl.text.isEmpty || _blocoCtrl.text.isEmpty || _apCtrl.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha Nome, Bloco e AP!"))); return; }
    final b = _blocoCtrl.text.trim().toUpperCase(), a = _apCtrl.text.trim(), n = _nomeCtrl.text.trim(), c = _codigoTemporarioLido;
    setState(() { _pacotes.insert(0, {'codigo': c, 'empresa': _empresaCtrl.text.trim(), 'nome': n, 'bloco': b, 'ap': a}); _codigoTemporarioLido = ""; _nomeCtrl.clear(); _blocoCtrl.clear(); _apCtrl.clear(); _estadoAtual = 1; });
    try { if ((await FirebaseFirestore.instance.collection('usuarios').doc(widget.emailSindico).get()).data()?['usar_impressora_etiquetas'] == true) await _imprimirEtiqueta(b, a, n, c); } catch (_) {}
  }

  void _finalizarLote() { final qtdInformada = int.tryParse(_qtdCtrl.text) ?? 0; if (_pacotes.length != qtdInformada) _abrirDialogoDivergencia(qtdInformada); else _processarSalvamentoNoBanco(false, ""); }

  void _abrirDialogoDivergencia(int qtdInformada) {
    String observacao = "";
    showDialog(context: context, builder: (ctxDiv) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: Row(children:[Icon(Icons.warning, color: colorScheme.error), const SizedBox(width: 10), const Text("Divergência Detectada!")]), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[Text("A quantidade informada ($qtdInformada) difere dos pacotes bipados (${_pacotes.length}).", style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 10), const Text("Por favor, justifyique esta divergência para a auditoria do Síndico:"), const SizedBox(height: 10), TextField(onChanged: (v) => observacao = v, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Ex: Entregador informou 3, mas só deixou 2 caixas."))]), actions:[TextButton(onPressed: () => Navigator.pop(ctxDiv), child: const Text("VOLTAR PARA REVISAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError), onPressed: () { if (observacao.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A observação é obrigatória em caso de divergência."))); return; } Navigator.pop(ctxDiv); _processarSalvamentoNoBanco(true, observacao); }, child: const Text("SALVAR COM DIVERGÊNCIA"))]);
    });
  }

  Future<void> _processarSalvamentoNoBanco(bool temDivergencia, String obs) async {
    final grupos = <String, List<Map<String, dynamic>>>{};
    for (var p in _pacotes) { final chave = "${p['nome'].toString().trim().toUpperCase()}_${p['bloco']}_${p['ap']}"; grupos.putIfAbsent(chave, () => []).add(p); }

    for (var chave in grupos.keys) {
      final pacotesDoAp = grupos[chave]!, b = pacotesDoAp.first['bloco'], a = pacotesDoAp.first['ap'], nDigitado = pacotesDoAp.first['nome'].toString().toUpperCase(), barras = pacotesDoAp.map((x) => x['codigo'].toString()).toList();
      final moradorCheck = await FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('perfil', isEqualTo: 'morador').where('bloco', isEqualTo: b).where('ap', isEqualTo: a).get();
      String nomeOficialMorador = nDigitado, emailOficialMorador = ""; bool destinatarioIndireto = true;

      if (moradorCheck.docs.isNotEmpty) {
        for(var docM in moradorCheck.docs) {
           final nomeReg = (docM.data()['nome'] ?? '').toString().toUpperCase(), palavrasDigitadas = nomeOficialMorador.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList(), palavrasRegistradas = nomeReg.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
           bool verificar(List<String> b, List<String> a) { int p = 0; for (final w in b) { int pos = -1; for (int j = p; j < a.length; j++) if (a[j] == w) { pos = j; break; } if (pos != -1) p = pos + 1; else return false; } return true; }
           if(verificar(palavrasDigitadas, palavrasRegistradas) || verificar(palavrasRegistradas, palavrasDigitadas)) { nomeOficialMorador = nomeReg; emailOficialMorador = docM.data()['email'] ?? docM.id; destinatarioIndireto = false; break; }
        }
      } else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aviso: Nenhum morador cadastrado neste Bloco/AP."), backgroundColor: Colors.orange));

      final snapExistente = await FirebaseFirestore.instance.collection('encomendas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('bloco', isEqualTo: b).where('ap', isEqualTo: a).where('morador', isEqualTo: nomeOficialMorador).where('status', isEqualTo: 'aguardando').get();
      if (snapExistente.docs.isNotEmpty) {
        final docExistente = snapExistente.docs.first, dataDoc = docExistente.data(), oldTemDivergencia = dataDoc['tem_divergencia'] ?? false, oldObsDivergencia = dataDoc['observacao_divergencia'] ?? "";
        await docExistente.reference.update({'codigos_barras': FieldValue.arrayUnion(barras), 'codigos_acesso': FieldValue.arrayUnion([(dataDoc['codigo'] ?? '')]), 'quantidade_informada': FieldValue.increment(pacotesDoAp.length), 'operador_recebimento': operadorLogado, 'entregador': _entregadorCtrl.text.trim(), 'empresa_entregadora': _empresaCtrl.text.trim(), 'tem_divergencia': temDivergencia ? true : oldTemDivergencia, 'observacao_divergencia': temDivergencia ? obs : oldObsDivergencia});
      } else {
        final pacotesAguardandoNesteAp = await FirebaseFirestore.instance.collection('encomendas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('bloco', isEqualTo: b).where('ap', isEqualTo: a).where('status', isEqualTo: 'aguardando').get();
        final pinsPorMorador = <String, String>{}; final codigosAcesso = <String>[]; String pinPrimario = (Random.secure().nextInt(9000) + 1000).toString();

        if (destinatarioIndireto) {
           for (var docM in moradorCheck.docs) {
             final emailM = docM.data()['email'] ?? docM.id; String pinDoMorador = (Random.secure().nextInt(9000) + 1000).toString();
             for (var pacote in pacotesAguardandoNesteAp.docs) { final pData = pacote.data(); if (pData.containsKey('pins_por_morador') && pData['pins_por_morador'][emailM] != null) { pinDoMorador = pData['pins_por_morador'][emailM]; break; } else if (pData['destinatario_indireto'] != true && pData['morador'] == docM.data()['nome']) { pinDoMorador = pData['codigo']; break; } }
             pinsPorMorador[emailM] = pinDoMorador; if (!codigosAcesso.contains(pinDoMorador)) codigosAcesso.add(pinDoMorador);
           }
           if (codigosAcesso.isEmpty) codigosAcesso.add(pinPrimario);
        } else {
           String pinJoao = pinPrimario;
           for (var pacote in pacotesAguardandoNesteAp.docs) { final pData = pacote.data(); if (pData.containsKey('pins_por_morador') && pData['pins_por_morador'][emailOficialMorador] != null) { pinJoao = pData['pins_por_morador'][emailOficialMorador]; break; } else if (pData['destinatario_indireto'] != true && pData['morador'] == nomeOficialMorador) { pinJoao = pData['codigo']; break; } }
           pinPrimario = pinJoao; codigosAcesso.add(pinPrimario); if (emailOficialMorador.isNotEmpty) pinsPorMorador[emailOficialMorador] = pinPrimario;
        }

        await FirebaseFirestore.instance.collection('encomendas').add({'sindico_vinculado': widget.emailSindico, 'morador': nomeOficialMorador, 'bloco': b, 'ap': a, 'codigos_barras': barras, 'codigos_bipados':[], 'codigo': pinPrimario, 'codigos_acesso': codigosAcesso, 'pins_por_morador': pinsPorMorador, 'status': 'aguardando', 'data_registro': FieldValue.serverTimestamp(), 'operador_recebimento': operadorLogado, 'entregador': _entregadorCtrl.text.trim(), 'empresa_entregadora': _empresaCtrl.text.trim(), 'quantidade_informada': pacotesDoAp.length, 'tem_divergencia': temDivergencia, 'observacao_divergencia': obs, 'destinatario_indireto': destinatarioIndireto});

        if (!destinatarioIndireto && pacotesAguardandoNesteAp.docs.isNotEmpty) {
           final batchUpdateFelizbina = FirebaseFirestore.instance.batch(); bool teveInjecao = false;
           for (var pacoteNaPrateleira in pacotesAguardandoNesteAp.docs) {
             if (pacoteNaPrateleira.data()['destinatario_indireto'] == true) { 
                final pData = pacoteNaPrateleira.data(), currentPins = pData.containsKey('pins_por_morador') ? Map<String, dynamic>.from(pData['pins_por_morador']) : {}, currentAcessos = pData.containsKey('codigos_acesso') ? List<dynamic>.from(pData['codigos_acesso']) : [];
                if (emailOficialMorador.isNotEmpty) currentPins[emailOficialMorador] = pinPrimario; if (!currentAcessos.contains(pinPrimario)) currentAcessos.add(pinPrimario);
                batchUpdateFelizbina.update(pacoteNaPrateleira.reference, {'codigos_acesso': currentAcessos, 'pins_por_morador': currentPins}); teveInjecao = true;
             }
           }
           if (teveInjecao) await batchUpdateFelizbina.commit();
        }
      }

      if (destinatarioIndireto) {
        if (moradorCheck.docs.isNotEmpty) for (var docM in moradorCheck.docs) await FirebaseFirestore.instance.collection('notificacoes').add({'sindico_vinculado': widget.emailSindico, 'para': (docM.data()['email'] ?? docM.id).toString().toLowerCase().trim(), 'nome_destino': 'Bloco $b AP $a - ${docM.data()['nome'] ?? ''}', 'titulo': '📦 ENCOMENDA NA PORTARIA!', 'mensagem': 'Vocês receberam ${pacotesDoAp.length} pacote(s) via ${_empresaCtrl.text.trim()}. Acesse o app para ver o PIN de retirada.', 'data': FieldValue.serverTimestamp(), 'remetente': 'Portaria', 'tipo_acao': 'acao_avisos'});
      } else if (emailOficialMorador.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notificacoes').add({'sindico_vinculado': widget.emailSindico, 'para': emailOficialMorador.toLowerCase().trim(), 'nome_destino': 'Bloco $b AP $a - $nomeOficialMorador', 'titulo': '📦 ENCOMENDA NA PORTARIA!', 'mensagem': 'Você recebeu ${pacotesDoAp.length} pacote(s) via ${_empresaCtrl.text.trim()}. Acesse o app para ver o seu PIN de retirada.', 'data': FieldValue.serverTimestamp(), 'remetente': 'Portaria', 'tipo_acao': 'acao_avisos'});
      }
    }

    await registrarAuditoria(widget.emailSindico, "Recebimento de Lote", "Encomendas", "Entregador: ${_entregadorCtrl.text} (${_empresaCtrl.text}). Bipados: ${_pacotes.length}.");
    if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lote registrado e atribuído aos apartamentos com sucesso!"), backgroundColor: Colors.green)); }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme, isDesktopOrWeb = kIsWeb || defaultTargetPlatform == TargetPlatform.windows;
    return AlertDialog(
      title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Recepção Inteligente de Encomendas")),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children:[
        if (_estadoAtual == 0) ...[const Text("Passo 1: Cabeçalho da Remessa", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 10), TextField(controller: _entregadorCtrl, decoration: const InputDecoration(labelText: "Nome do Entregador", border: OutlineInputBorder())), const SizedBox(height: 10), Row(children:[Expanded(flex: 2, child: TextField(controller: _empresaCtrl, decoration: const InputDecoration(labelText: "Empresa (Ex: Correios)", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(flex: 1, child: TextField(controller: _qtdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Qtd. Total", border: OutlineInputBorder())))]), const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, padding: const EdgeInsets.all(15)), onPressed: _iniciarSessao, child: const FittedBox(fit: BoxFit.scaleDown, child: Text("INICIAR LOTE", style: TextStyle(fontWeight: FontWeight.bold)))))]
        else if (_estadoAtual == 1) ...[Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(5)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Entregador: ${_entregadorCtrl.text}", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer))), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Empresa: ${_empresaCtrl.text}", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer.withValues(alpha:0.7))))])), FittedBox(fit: BoxFit.scaleDown, child: Text("Total: ${_qtdCtrl.text} vols.", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 16)))])), const SizedBox(height: 15), const Text("Lista de Pacotes no Lote Atual:", style: TextStyle(fontWeight: FontWeight.bold)), Container(height: 200, margin: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(5)), child: _pacotes.isEmpty ? const Center(child: Text("Nenhum pacote bipado ainda.", style: TextStyle(color: Colors.grey))) : ListView.builder(itemCount: _pacotes.length, itemBuilder: (ctx, i) { final p = _pacotes[i]; return ListTile(dense: true, leading: const Icon(Icons.check_circle, color: Colors.green), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("${p['codigo']} (${p['empresa']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))), subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("B: ${p['bloco']} AP: ${p['ap']} - ${p['nome']}", style: const TextStyle(fontSize: 11))), trailing: IconButton(icon: Icon(Icons.delete, color: colorScheme.error, size: 18), onPressed: () => setState(() => _pacotes.removeAt(i)))); })), TextField(controller: _codigoManualCtrl, autofocus: isDesktopOrWeb, decoration: InputDecoration(labelText: isDesktopOrWeb ? "Bipe o código do pacote (Leitor USB)" : "Digitar Código Manualmente", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(Icons.send, color: colorScheme.primary), onPressed: () => _processarCodigoLido(_codigoManualCtrl.text))), onSubmitted: _processarCodigoLido), const SizedBox(height: 10), if (!isDesktopOrWeb) SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: colorScheme.onSecondary, padding: const EdgeInsets.all(15)), icon: const Icon(Icons.qr_code_scanner), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("OU ESCANEAR COM A CÂMERA", style: TextStyle(fontWeight: FontWeight.bold))), onPressed: _iniciarEscaneamentoMobile))]
        else if (_estadoAtual == 2) ...[Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(5), border: Border.all(color: colorScheme.secondary)), child: Column(children:[Text("CÓDIGO ENCONTRADO:", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSecondaryContainer)), const SizedBox(height: 5), FittedBox(fit: BoxFit.scaleDown, child: Text(_codigoTemporarioLido, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2, color: colorScheme.onSecondaryContainer)))])), const SizedBox(height: 20), const Text("Preencha os dados da etiqueta para este pacote:", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 10), Row(children:[Expanded(child: TextField(controller: _blocoCtrl, decoration: const InputDecoration(labelText: "Bloco", border: OutlineInputBorder()), autofocus: true)), const SizedBox(width: 10), Expanded(child: TextField(controller: _apCtrl, decoration: const InputDecoration(labelText: "Apartamento", border: OutlineInputBorder())))]), const SizedBox(height: 10), TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: "Nome Exato na Etiqueta", border: OutlineInputBorder()), inputFormatters:[UpperCaseTextFormatter()]), const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(15)), icon: const Icon(Icons.save), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("SALVAR PACOTE NO LOTE", style: TextStyle(fontWeight: FontWeight.bold))), onPressed: _salvarPacoteLido))]
      ]))),
      actions:[if (_estadoAtual == 2) TextButton(onPressed: () => setState(() { _codigoTemporarioLido = ""; _estadoAtual = 1; }), child: Text("CANCELAR PACOTE", style: TextStyle(color: colorScheme.error))) else TextButton(onPressed: () => Navigator.pop(context), child: const Text("SAIR")), if (_estadoAtual == 1 && _pacotes.isNotEmpty) ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), icon: const Icon(Icons.done_all), onPressed: _finalizarLote, label: const FittedBox(fit: BoxFit.scaleDown, child: Text("FINALIZAR LOTE")))]
    );
  }
}

class TelaEstoque extends StatefulWidget {
  final String emailSindico, perfil; 
  const TelaEstoque({super.key, required this.emailSindico, required this.perfil});
  @override
  State<TelaEstoque> createState() => _TelaEstoqueState();
}

class _TelaEstoqueState extends State<TelaEstoque> with WidgetsBindingObserver {
  String busca = ""; String? blocoSelecionado, apSelecionado; DateTime? _dataFiltroInicio, _dataFiltroFim;
  late Stream<QuerySnapshot> _estoquePendenteStream;
  List<Map<String, dynamic>> _historicoCache = [];
  bool _carregandoHistorico = true, _buscandoNuvem = false, _fimDoHistorico = false;
  final _scrollController = ScrollController();
  StreamSubscription<QuerySnapshot>? _novasEntregasSub;
  String _erroFirebaseIndex = "";

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _scrollController.addListener(_aoRolarTela); _initStreams(); _carregarHistoricoDeltaSync(); }

  void _aoRolarTela() { if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_buscandoNuvem && !_fimDoHistorico && _historicoCache.isNotEmpty && busca.isEmpty && _dataFiltroInicio == null) _buscarMaisAntigosNaNuvem(); }

  void _initStreams() { _estoquePendenteStream = FirebaseFirestore.instance.collection('encomendas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('status', whereIn:['aguardando', 'em_retirada', 'confirmado_morador']).snapshots(); }

  Future<void> _salvarCacheLocal(List<Map<String, dynamic>> lista) async {
    try {
      final jsonStr = jsonEncode(lista.map((item) => item.map((key, value) => MapEntry(key, value is Timestamp ? value.toDate().toIso8601String() : value))).toList());
      if (kIsWeb) await (await SharedPreferences.getInstance()).setString('estoque_hist_${widget.emailSindico}', jsonStr);
      else await File('${(await getApplicationDocumentsDirectory()).path}/estoque_hist_${widget.emailSindico}.json').writeAsString(jsonStr);
    } catch (_) {}
  }

  Future<void> _carregarHistoricoDeltaSync() async {
    try {
      String jsonString = "";
      if (kIsWeb) jsonString = (await SharedPreferences.getInstance()).getString('estoque_hist_${widget.emailSindico}') ?? "";
      else { final file = File('${(await getApplicationDocumentsDirectory()).path}/estoque_hist_${widget.emailSindico}.json'); if (await file.exists()) jsonString = await file.readAsString(); }

      if (jsonString.isNotEmpty) {
        _historicoCache = (jsonDecode(jsonString) as List).map((item) { final mapa = Map<String, dynamic>.from(item); if (mapa['data_entrega'] != null && mapa['data_entrega'] is String) mapa['data_entrega'] = Timestamp.fromDate(DateTime.parse(mapa['data_entrega'])); if (mapa['data_registro'] != null && mapa['data_registro'] is String) mapa['data_registro'] = Timestamp.fromDate(DateTime.parse(mapa['data_registro'])); return mapa; }).toList();
      }
      if (mounted) setState(() => _carregandoHistorico = false);

      Timestamp? ultimaData;
      if (_historicoCache.isNotEmpty) { _historicoCache.sort((a, b) => (b['data_entrega'] as Timestamp).compareTo(a['data_entrega'] as Timestamp)); ultimaData = _historicoCache.first['data_entrega'] as Timestamp; }

      if (ultimaData == null) {
        if (mounted) setState(() => _buscandoNuvem = true);
        for (var doc in (await FirebaseFirestore.instance.collection('encomendas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('status', isEqualTo: 'entregue').orderBy('data_entrega', descending: true).limit(20).get()).docs) _historicoCache.add(doc.data()..['id'] = doc.id);
        if (mounted) setState(() => _buscandoNuvem = false); await _salvarCacheLocal(_historicoCache);
      } else {
        final snapNovos = await FirebaseFirestore.instance.collection('encomendas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('status', isEqualTo: 'entregue').where('data_entrega', isGreaterThan: ultimaData).get();
        if (snapNovos.docs.isNotEmpty) { for (var doc in snapNovos.docs) _historicoCache.insert(0, doc.data()..['id'] = doc.id); _historicoCache.sort((a, b) => (b['data_entrega'] as Timestamp).compareTo(a['data_entrega'] as Timestamp)); if (mounted) setState(() {}); await _salvarCacheLocal(_historicoCache); }
      }

      _novasEntregasSub?.cancel();
      _novasEntregasSub = FirebaseFirestore.instance.collection('encomendas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('status', isEqualTo: 'entregue').where('data_entrega', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 3)))).snapshots().listen((snap) {
        bool alterou = false;
        for (var change in snap.docChanges) {
          final data = change.doc.data()!..['id'] = change.doc.id; final index = _historicoCache.indexWhere((v) => v['id'] == change.doc.id);
          if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) { if (index != -1) _historicoCache[index] = data; else _historicoCache.insert(0, data); alterou = true; } else if (change.type == DocumentChangeType.removed && index != -1) { _historicoCache.removeAt(index); alterou = true; }
        }
        if (alterou) { _historicoCache.sort((a, b) => (b['data_entrega'] as Timestamp).compareTo(a['data_entrega'] as Timestamp)); if (mounted) setState(() {}); _salvarCacheLocal(_historicoCache); }
      }, onError: (e) {
        if (mounted) setState(() => _erroFirebaseIndex = e.toString());
      });
    } catch (e) { 
      if (mounted) {
        setState(() {
          _carregandoHistorico = false;
          _buscandoNuvem = false;
          if (e.toString().contains('index') || e.toString().contains('FAILED_PRECONDITION')) _erroFirebaseIndex = e.toString();
        });
      }
    }
  }

  Future<void> _buscarMaisAntigosNaNuvem() async {
    setState(() => _buscandoNuvem = true);
    try {
      final dataMaisVelha = _historicoCache.isNotEmpty ? _historicoCache.last['data_entrega'] as Timestamp? : null;
      if (dataMaisVelha != null) {
        final snap = await FirebaseFirestore.instance.collection('encomendas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('status', isEqualTo: 'entregue').where('data_entrega', isLessThan: dataMaisVelha).orderBy('data_entrega', descending: true).limit(20).get();
        if (snap.docs.isNotEmpty) { for (var doc in snap.docs) { final data = doc.data()..['id'] = doc.id; if (!_historicoCache.any((m) => m['id'] == doc.id)) _historicoCache.add(data); } if (mounted) setState(() {}); await _salvarCacheLocal(_historicoCache); } else _fimDoHistorico = true;
      }
    } catch (e) {
      if (mounted && (e.toString().contains('index') || e.toString().contains('FAILED_PRECONDITION'))) setState(() => _erroFirebaseIndex = e.toString());
    }
    if (mounted) setState(() => _buscandoNuvem = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) FirebaseAuth.instance.currentUser?.getIdToken(true); }

  Future<void> _reconectarBancoDeDados() async { try { await FirebaseAuth.instance.currentUser?.getIdToken(true); setState(() { _initStreams(); _carregarHistoricoDeltaSync(); }); } catch (_) {} }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _scrollController.dispose(); _novasEntregasSub?.cancel(); super.dispose(); }

  Future<void> _selecionarDataFiltro(BuildContext context) async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now(), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme), child: child!));
    if (picked != null) setState(() { _dataFiltroInicio = picked.start; _dataFiltroFim = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59); });
  }

// [FIM DO BLOCO - DIGITE "CONTINUE" PARA GERAR A PRÓXIMA PARTE]
void _editarEncomenda(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nomeC = TextEditingController(text: data['morador']), blocoC = TextEditingController(text: data['bloco']), apC = TextEditingController(text: data['ap']);
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Editar Encomenda")),
        content: Column(mainAxisSize: MainAxisSize.min, children:[TextField(controller: blocoC, decoration: const InputDecoration(labelText: "Bloco Corrigido", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: apC, decoration: const InputDecoration(labelText: "AP Corrigido", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: nomeC, inputFormatters:[UpperCaseTextFormatter()], decoration: const InputDecoration(labelText: "Nome Exato do Morador", border: OutlineInputBorder()))]),
        actions:[TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async { await doc.reference.update({'bloco': blocoC.text.trim().toUpperCase(), 'ap': apC.text.trim(), 'morador': nomeC.text.trim().toUpperCase(), 'editado_sindico': true}); await registrarAuditoria(widget.emailSindico, "Edição de Pacote", "Estoque", "Pacote ajustado para ${nomeC.text} (B: ${blocoC.text} AP: ${apC.text})"); if (mounted) Navigator.pop(ctx); }, child: const Text("SALVAR"))]
      );
    });
  }

  void _excluirEncomenda(DocumentSnapshot doc) {
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text("Excluir Pacote", style: TextStyle(color: colorScheme.error)),
        content: const Text("Tem certeza? Esta ação removerá o pacote do estoque para sempre."),
        actions:[TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError), onPressed: () async { await doc.reference.delete(); await registrarAuditoria(widget.emailSindico, "Exclusão de Pacote", "Estoque", "Síndico deletou um registro do estoque."); if (mounted) Navigator.pop(ctx); }, child: const Text("EXCLUIR"))]
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(length: 2, child: Scaffold(
      appBar: TabBar(key: keyTutEncAbas, labelColor: colorScheme.primary, unselectedLabelColor: colorScheme.onSurfaceVariant, indicatorColor: colorScheme.primary, tabs: const [Tab(icon: Icon(Icons.inventory), text: "Estoque na Portaria"), Tab(icon: Icon(Icons.history), text: "Histórico de Entregas")]),
      body: TabBarView(children: [_buildAbaEstoque(isHistorico: false), _buildAbaEstoque(isHistorico: true)]),
    ));
  }

  Widget _buildAbaEstoque({required bool isHistorico}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
      Padding(padding: const EdgeInsets.all(16), child: Row(children:[
        Expanded(child: TextField(key: !isHistorico ? keyTutEstBusca : null, onChanged: (v) => setState(() => busca = v.toLowerCase()), decoration: const InputDecoration(labelText: "Pesquisar (Nome, Bloco-AP ou Rastreio. Ex: 10-12)", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
        if (isHistorico) ...[const SizedBox(width: 10), FittedBox(fit: BoxFit.scaleDown, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: _dataFiltroInicio != null ? colorScheme.primary : colorScheme.surfaceContainerHighest, foregroundColor: _dataFiltroInicio != null ? colorScheme.onPrimary : colorScheme.onSurfaceVariant, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15)), icon: const Icon(Icons.calendar_month), label: Text(_dataFiltroInicio != null ? "${DateFormat('dd/MM').format(_dataFiltroInicio!)} - ${DateFormat('dd/MM').format(_dataFiltroFim!)}" : "Filtrar Data"), onPressed: () => _selecionarDataFiltro(context))), if (_dataFiltroInicio != null) IconButton(icon: Icon(Icons.clear, color: colorScheme.error), onPressed: () => setState(() { _dataFiltroInicio = null; _dataFiltroFim = null; }))]
      ])),
      if (busca.isEmpty && !isHistorico) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:[TextButton.icon(icon: const Icon(Icons.business), label: const Text("Todos os Blocos"), onPressed: () => setState(() { blocoSelecionado = null; apSelecionado = null; })), if (blocoSelecionado != null) ...[const Icon(Icons.chevron_right, color: Colors.grey), TextButton.icon(icon: const Icon(Icons.meeting_room), label: Text("Bloco $blocoSelecionado"), onPressed: () => setState(() => apSelecionado = null))], if (apSelecionado != null) ...[const Icon(Icons.chevron_right, color: Colors.grey), TextButton.icon(icon: const Icon(Icons.person), label: Text("AP $apSelecionado"), onPressed: () {})]]))),
      Expanded(child: isHistorico ? Builder(builder: (context) {
        if (_erroFirebaseIndex.isNotEmpty) return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: SelectableText("O Firebase exige um Índice para mostrar o histórico.\n\nCopie o link gerado abaixo e cole no navegador para o Firebase criar a regra automaticamente:\n\n$_erroFirebaseIndex", style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold), textAlign: TextAlign.center)));
        if (_carregandoHistorico) return const Center(child: CircularProgressIndicator());
        final todosDocs = _historicoCache.where((data) {
          if (_dataFiltroInicio != null && data['data_entrega'] != null) { final dtEnt = (data['data_entrega'] as Timestamp).toDate(); if (dtEnt.isBefore(_dataFiltroInicio!) || dtEnt.isAfter(_dataFiltroFim!)) return false; }
          if (busca.isNotEmpty) { final nome = (data['morador'] ?? '').toString().toLowerCase(), bloco = (data['bloco'] ?? '').toString().toLowerCase(), ap = (data['ap'] ?? '').toString().toLowerCase(), temCodigo = (data['codigos_barras'] ?? []).any((c) => c.toString().toLowerCase().contains(busca)); return nome.contains(busca) || bloco.contains(busca) || ap.contains(busca) || temCodigo || "$bloco-$ap".contains(busca.replaceAll(' ', '')); }
          return true;
        }).toList();
        return _buildListaPacotesExtrato(todosDocs, true);
      }) : StreamBuilder<QuerySnapshot>(stream: _estoquePendenteStream, builder: (context, snap) {
        if (snap.hasError) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.wifi_off, size: 50, color: colorScheme.error), const SizedBox(height: 15), Text("Sessão expirada ou erro de conexão.", style: TextStyle(color: colorScheme.onSurfaceVariant)), const SizedBox(height: 10), ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("Recarregar"), onPressed: _reconectarBancoDeDados)]));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final todosDocs = snap.data!.docs.toList();
        if (busca.isNotEmpty) return _buildListaPacotesExtrato(todosDocs.where((d) { final data = d.data() as Map<String, dynamic>, nome = (data['morador'] ?? '').toString().toLowerCase(), bloco = (data['bloco'] ?? '').toString().toLowerCase(), ap = (data['ap'] ?? '').toString().toLowerCase(), temCodigo = (data['codigos_barras'] ?? []).any((c) => c.toString().toLowerCase().contains(busca)); return nome.contains(busca) || bloco.contains(busca) || ap.contains(busca) || temCodigo || "$bloco-$ap".contains(busca.replaceAll(' ', '')); }).toList(), false);
        if (blocoSelecionado == null) {
          final blocosSet = todosDocs.map((d) => (d.data() as Map)['bloco'].toString().toUpperCase()).toSet().toList()..sort();
          if (blocosSet.isEmpty) return const Center(child: Text("Estoque vazio."));
          return GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, childAspectRatio: 1.2, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: blocosSet.length, itemBuilder: (context, index) {
            final bloco = blocosSet[index], qtdPacotes = todosDocs.where((d) => (d.data() as Map)['bloco'].toString().toUpperCase() == bloco).length;
            return InkWell(onTap: () => setState(() => blocoSelecionado = bloco), child: Card(color: colorScheme.primaryContainer, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: colorScheme.primary.withValues(alpha:0.3))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.business, size: 50, color: colorScheme.primary), const SizedBox(height: 10), FittedBox(fit: BoxFit.scaleDown, child: Text("Bloco $bloco", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer))), FittedBox(fit: BoxFit.scaleDown, child: Text("$qtdPacotes Remessas", style: TextStyle(color: colorScheme.onPrimaryContainer.withValues(alpha:0.7))))])));
          });
        }
        if (apSelecionado == null) {
          final docsBloco = todosDocs.where((d) => (d.data() as Map)['bloco'].toString().toUpperCase() == blocoSelecionado).toList(), apsSet = docsBloco.map((d) => (d.data() as Map)['ap'].toString()).toSet().toList()..sort();
          return GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 150, childAspectRatio: 1.0, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: apsSet.length, itemBuilder: (context, index) {
            final ap = apsSet[index], qtdPacotes = docsBloco.where((d) => (d.data() as Map)['ap'].toString() == ap).length;
            return InkWell(onTap: () => setState(() => apSelecionado = ap), child: Card(color: colorScheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: colorScheme.outlineVariant)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.meeting_room, size: 40, color: colorScheme.onSurfaceVariant), const SizedBox(height: 10), FittedBox(fit: BoxFit.scaleDown, child: Text("AP $ap", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface))), FittedBox(fit: BoxFit.scaleDown, child: Text("$qtdPacotes Remessas", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)))])));
          });
        }
        return _buildListaPacotesExtrato(todosDocs.where((d) => (d.data() as Map)['bloco'].toString().toUpperCase() == blocoSelecionado && (d.data() as Map)['ap'].toString() == apSelecionado).toList(), false);
      }))
    ]);
  }

  void _mostrarObservacaoDivergencia(String observacao) {
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: Row(children:[Icon(Icons.warning, color: colorScheme.error), const SizedBox(width: 10), const Text("Divergência de Recebimento")]), content: Text(observacao), actions:[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FECHAR"))]);
    });
  }

  Widget _buildListaPacotesExtrato(List<dynamic> lista, bool isHistorico) {
    if (lista.isEmpty) return const Center(child: Text("Nenhuma encomenda encontrada."));
    lista.sort((a, b) => (((b is DocumentSnapshot ? b.data() as Map : b)['data_registro'] as Timestamp?) ?? Timestamp.now()).compareTo(((a is DocumentSnapshot ? a.data() as Map : a)['data_registro'] as Timestamp?) ?? Timestamp.now()));
    final isSindico = widget.perfil == 'sindico', colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      controller: isHistorico ? _scrollController : null,
      padding: const EdgeInsets.all(16),
      itemCount: lista.length + (isHistorico && _buscandoNuvem ? 1 : 0),
      itemBuilder: (context, index) {
        if (isHistorico && _buscandoNuvem && index == lista.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Buscando mais antigos na nuvem...", style: TextStyle(color: Colors.grey))])));
        final item = lista[index], doc = item is DocumentSnapshot ? item : null, data = item is DocumentSnapshot ? item.data() as Map<String, dynamic> : item;
        final codigosBarras = data['codigos_barras'] ?? [], codigosBipados = data['codigos_bipados'] ?? [], temDiv = data['tem_divergencia'] ?? false, foiEditado = data['editado_sindico'] ?? false, indireto = data['destinatario_indireto'] == true;
        final dataEnt = data['data_registro'] != null ? DateFormat('dd/MM/yyyy').format((data['data_registro'] as Timestamp).toDate()) : "N/D", horaEnt = data['data_registro'] != null ? DateFormat('HH:mm').format((data['data_registro'] as Timestamp).toDate()) : "N/D", dataRet = data['data_entrega'] != null ? DateFormat('dd/MM/yyyy').format((data['data_entrega'] as Timestamp).toDate()) : "N/D", horaRet = data['data_entrega'] != null ? DateFormat('HH:mm').format((data['data_entrega'] as Timestamp).toDate()) : "N/D";

        return Card(elevation: 4, margin: const EdgeInsets.only(bottom: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: Stack(children:[
          Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
            Row(crossAxisAlignment: CrossAxisAlignment.center, children:[
              Icon(isHistorico ? Icons.check_circle : Icons.inventory_2, color: isHistorico ? Colors.green : colorScheme.primary, size: 30), const SizedBox(width: 10),
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Bloco: ${data['bloco'] ?? 'N/D'} | AP: ${data['ap'] ?? 'N/D'}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
              if (isSindico && !isHistorico && doc != null) Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(Icons.edit, color: colorScheme.primary), padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: "Editar", onPressed: () => _editarEncomenda(doc)), const SizedBox(width: 10), IconButton(icon: Icon(Icons.delete, color: colorScheme.error), padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: "Excluir", onPressed: () => _excluirEncomenda(doc))])
            ]), const Divider(height: 20, thickness: 1),
            RichText(text: TextSpan(style: TextStyle(color: colorScheme.onSurface, fontSize: 13, height: 1.5), children:[const TextSpan(text: "Dest: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${data['morador']?.toString().toUpperCase() ?? 'N/D'} | "), const TextSpan(text: "Data de ent: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "$dataEnt | "), const TextSpan(text: "Hora da entrega: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "$horaEnt | "), const TextSpan(text: "Porteiro: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${data['operador_recebimento'] ?? 'N/D'} | "), const TextSpan(text: "Entregador: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${data['empresa_entregadora'] ?? 'N/D'} | "), const TextSpan(text: "Quantidade: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${codigosBarras.length}")])), const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: codigosBarras.isEmpty ? <Widget>[Text("Nenhum código registrado", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: colorScheme.onSurfaceVariant))] : codigosBarras.map<Widget>((c) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(5), border: Border.all(color: colorScheme.primary.withValues(alpha:0.3))), child: Text("📦 $c", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer)))).toList()),
            if (isHistorico || data['status'] == 'confirmado_morador') ...[const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(thickness: 1)), RichText(text: TextSpan(style: TextStyle(color: colorScheme.onSurface, fontSize: 13, height: 1.5), children:[const TextSpan(text: "Data da retirada: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "$dataRet | "), const TextSpan(text: "Hora da retirada: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "$horaRet | "), const TextSpan(text: "Porteiro: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${data['operador_entrega'] ?? 'N/D'} | "), const TextSpan(text: "Morador que assinou: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${data['quem_retirou'] ?? 'N/D'} | "), const TextSpan(text: "Volumes entregues: ", style: TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: "${codigosBipados.length}"), if (indireto) ...[const TextSpan(text: " | Moradores não cadastrados: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)), TextSpan(text: "${data['morador']}", style: const TextStyle(color: Colors.orange))]])), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: codigosBipados.isEmpty ? <Widget>[Text("Nenhum código bipado na retirada", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: colorScheme.onSurfaceVariant))] : codigosBipados.map<Widget>((c) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.withValues(alpha:0.1), borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.green.withValues(alpha:0.5))), child: Text("✅ $c", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)))).toList())],
            if (!isHistorico && data['status'] == 'confirmado_morador' && doc != null) ...[const SizedBox(height: 15), Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)), child: Column(children:[const FittedBox(fit: BoxFit.scaleDown, child: Text("✅ Morador assinou/confirmou no App!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14))), const SizedBox(height: 10), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), icon: const Icon(Icons.check), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("CONCLUIR ENTREGA")), onPressed: () async { await doc.reference.update({'status': 'entregue', 'data_entrega': FieldValue.serverTimestamp(), 'operador_entrega': operadorLogado}); await registrarAuditoria(widget.emailSindico, "Entrega de Encomendas", "Encomendas", "Concluído pelo porteiro (AP: ${data['ap']})."); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entrega finalizada com sucesso!"))); })]))],
            if (foiEditado) Container(margin: const EdgeInsets.only(top: 15), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withValues(alpha:0.1), borderRadius: BorderRadius.circular(5)), child: const Row(mainAxisSize: MainAxisSize.min, children:[Icon(Icons.edit_note, size: 14, color: Colors.orange), SizedBox(width: 5), FittedBox(fit: BoxFit.scaleDown, child: Text("Ajustado Manualmente pelo Síndico", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)))]))
          ])),
          if (temDiv) Positioned(top: 15, right: 15, child: IconButton(icon: Icon(Icons.warning, color: colorScheme.error, size: 30), tooltip: "Ver Divergência", onPressed: () => _mostrarObservacaoDivergencia(data['observacao_divergencia'] ?? 'Sem observação detalhada.')))
        ]));
      },
    );
  }
}

// ============================================================================
// PARTE 7 - VISITANTES E CONTROLE DE ACESSO (PORTARIA)
// ============================================================================

class DialogCapturaCamera extends StatefulWidget {
  final String titulo;
  final bool forcarCameraFrontal;
  const DialogCapturaCamera({super.key, required this.titulo, this.forcarCameraFrontal = false});
  @override
  State<DialogCapturaCamera> createState() => _DialogCapturaCameraState();
}

class _DialogCapturaCameraState extends State<DialogCapturaCamera> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraDescription? _cameraSelecionada;
  bool _isLocked = false, _isInitializing = true, _capturando = false;

  @override
  void initState() { super.initState(); _iniciarSistemaDeCamera(); }

  Future<void> _iniciarSistemaDeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) { if (mounted) { Navigator.pop(context, null); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nenhuma webcam detectada!"), backgroundColor: Colors.red)); } return; }
      
      if (widget.forcarCameraFrontal) {
         try {
           _cameraSelecionada = _cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
         } catch (_) {
           _cameraSelecionada = _cameras.first;
         }
         await _ligarCamera(_cameraSelecionada!);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final camIdSalva = prefs.getString('cam_id');
        _isLocked = prefs.getBool('cam_locked') ?? false;
        _cameraSelecionada = camIdSalva != null ? _cameras.firstWhere((c) => c.name == camIdSalva, orElse: () => _cameras.first) : _cameras.first;
        if (_isLocked) await _ligarCamera(_cameraSelecionada!); else setState(() => _isInitializing = false);
      }
    } catch (_) { if (mounted) Navigator.pop(context, null); }
  }

  Future<void> _ligarCamera(CameraDescription cam) async {
    setState(() => _isInitializing = true);
    if (_controller != null) { await _controller!.dispose(); await Future.delayed(const Duration(milliseconds: 300)); }
    _controller = CameraController(cam, ResolutionPreset.medium, enableAudio: false);
    try { await _controller!.initialize(); } catch (_) {}
    if (mounted) setState(() => _isInitializing = false);
  }

  Future<void> _salvarPreferencias() async { if (_cameraSelecionada != null) { final prefs = await SharedPreferences.getInstance(); await prefs.setString('cam_id', _cameraSelecionada!.name); await prefs.setBool('cam_locked', _isLocked); } }

  Future<void> _processarEFechar() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _capturando = true);
    try {
      final foto = await _controller!.takePicture();
      Uint8List bytes = await foto.readAsBytes();
      await _controller!.dispose(); _controller = null;
      if (defaultTargetPlatform == TargetPlatform.windows) {
        var imagemDecodificada = img.decodeImage(bytes);
        if (imagemDecodificada != null) {
          if (imagemDecodificada.width > 800 || imagemDecodificada.height > 800) imagemDecodificada = imagemDecodificada.width > imagemDecodificada.height ? img.copyResize(imagemDecodificada, width: 800) : img.copyResize(imagemDecodificada, height: 800);
          bytes = img.encodeJpg(imagemDecodificada, quality: 75);
        } else { if (mounted) { Navigator.pop(context, null); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A câmera gerou uma imagem inválida."), backgroundColor: Colors.red)); } return; }
      }
      if (mounted) Navigator.pop(context, bytes);
    } catch (_) { if (mounted) Navigator.pop(context, null); }
  }

  @override
  void dispose() { _controller?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: FittedBox(fit: BoxFit.scaleDown, child: Text(widget.titulo)),
      content: SizedBox(width: 550, child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!widget.forcarCameraFrontal) ...[
          if (!_isLocked) Row(children: [Expanded(child: DropdownButtonFormField<CameraDescription>(isExpanded: true, initialValue: _cameraSelecionada, decoration: const InputDecoration(labelText: "Selecione a Câmera", border: OutlineInputBorder()), items: _cameras.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(), onChanged: (v) { if (v != null) { setState(() => _cameraSelecionada = v); _ligarCamera(v); } })), const SizedBox(width: 10), IconButton(icon: Icon(Icons.lock_open, color: colorScheme.secondary, size: 30), tooltip: "Travar Escolha", onPressed: () { if (_cameraSelecionada != null) { setState(() => _isLocked = true); _salvarPreferencias(); if (_controller == null || !_controller!.value.isInitialized) _ligarCamera(_cameraSelecionada!); } })])
          else Row(children: [const Icon(Icons.lock, color: Colors.green), const SizedBox(width: 10), Expanded(child: Text("Câmera Padrão: ${_cameraSelecionada?.name}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))), TextButton(onPressed: () { setState(() => _isLocked = false); _salvarPreferencias(); }, child: const Text("DESTRAVAR"))]),
          const SizedBox(height: 15),
        ],
        Container(height: 300, width: double.infinity, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(border: Border.all(color: colorScheme.primary, width: 2), borderRadius: BorderRadius.circular(10)), child: _isInitializing ? const Center(child: CircularProgressIndicator()) : (_controller != null && _controller!.value.isInitialized && !_capturando) ? CameraPreview(_controller!) : const Center(child: Text("Processando foto..."))),
        if (_capturando) ...[const SizedBox(height: 15), const CircularProgressIndicator(), const SizedBox(height: 10), FittedBox(fit: BoxFit.scaleDown, child: Text("Otimizando e salvando imagem...", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)))]
      ])),
      actions: [TextButton(onPressed: _capturando ? null : () => Navigator.pop(context, null), child: const Text("CANCELAR", style: TextStyle(color: Colors.red))), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), icon: const Icon(Icons.camera_alt), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("CAPTURAR AGORA")), onPressed: (_capturando || _controller == null || !_controller!.value.isInitialized) ? null : _processarEFechar)]
    );
  }
}

class TelaGestaoFacial extends StatefulWidget {
  final String emailSindico, perfil;
  const TelaGestaoFacial({super.key, required this.emailSindico, required this.perfil});
  @override
  State<TelaGestaoFacial> createState() => _TelaGestaoFacialState();
}

class _TelaGestaoFacialState extends State<TelaGestaoFacial> with WidgetsBindingObserver {
  String busca = "";
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _moradoresCache = [];
  bool _carregandoMoradores = true, _buscandoNuvem = false;
  StreamSubscription<QuerySnapshot>? _novosAprovadosSub;
  int _limiteVisivel = 30;
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceBusca;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _scrollController.addListener(_aoRolarTela); _carregarMoradoresDeltaSync(); }

  void _aoRolarTela() { if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_buscandoNuvem) { setState(() => _limiteVisivel += 30); if (_limiteVisivel > _moradoresCache.length) _buscarMaisAntigosNaNuvem(); } }

  void _aoDigitarBusca(String valor) {
    setState(() => busca = valor.toLowerCase().trim());
    if (busca.isEmpty) return;
    _debounceBusca?.cancel();
    _debounceBusca = Timer(const Duration(milliseconds: 800), () async {
      if (!_moradoresCache.any((m) => (m['nome'] ?? '').toString().toLowerCase().contains(busca) || (m['bloco'] ?? '').toString().toLowerCase().contains(busca) || (m['ap'] ?? '').toString().toLowerCase().contains(busca))) {
        setState(() => _buscandoNuvem = true);
        try {
          final termoUpper = busca.toUpperCase(), snap = await FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('perfil', isEqualTo: 'morador').where('nome', isGreaterThanOrEqualTo: termoUpper).where('nome', isLessThan: '${termoUpper}z').limit(10).get();
          if (snap.docs.isNotEmpty) {
            bool salvouAlgo = false;
            for (final doc in snap.docs) { final data = doc.data()..['id'] = doc.id; if (!_moradoresCache.any((m) => m['id'] == doc.id)) { _moradoresCache.insert(0, data); salvouAlgo = true; } }
            if (salvouAlgo) { if (mounted) setState(() {}); _salvarCacheLocal(_moradoresCache); }
          }
        } catch (_) {}
        if (mounted) setState(() => _buscandoNuvem = false);
      }
    });
  }

  Future<void> _buscarMaisAntigosNaNuvem() async {
    // Obsoleto: O novo stream inteligente já traz todos os moradores em tempo real.
  }

  Future<void> _salvarCacheLocal(List<Map<String, dynamic>> lista) async {
    try {
      final jsonStr = jsonEncode(lista.map((item) => item.map((k, v) => MapEntry(k, v is Timestamp ? v.toDate().toIso8601String() : v))).toList());
      if (kIsWeb) await (await SharedPreferences.getInstance()).setString('bio_delta_${widget.emailSindico}', jsonStr);
      else await File('${(await getApplicationDocumentsDirectory()).path}/bio_delta_${widget.emailSindico}.json').writeAsString(jsonStr);
    } catch (_) {}
  }

  Future<void> _carregarMoradoresDeltaSync({bool forcarNuvem = false}) async {
    try {
      if (forcarNuvem) {
        setState(() => _carregandoMoradores = true);
        final snap = await FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('perfil', isEqualTo: 'morador').get(const GetOptions(source: Source.server));
        _moradoresCache = snap.docs.map((d) => d.data()..['id'] = d.id).toList();
        if (mounted) setState(() => _carregandoMoradores = false); await _salvarCacheLocal(_moradoresCache); return;
      }
      
      String jsonString = "";
      if (kIsWeb) jsonString = (await SharedPreferences.getInstance()).getString('bio_delta_${widget.emailSindico}') ?? "";
      else { final file = File('${(await getApplicationDocumentsDirectory()).path}/bio_delta_${widget.emailSindico}.json'); if (await file.exists()) jsonString = await file.readAsString(); }
      if (jsonString.isNotEmpty) {
        _moradoresCache = (jsonDecode(jsonString) as List).map((item) { final mapa = Map<String, dynamic>.from(item); if (mapa['data_aprovacao'] != null && mapa['data_aprovacao'] is String) mapa['data_aprovacao'] = Timestamp.fromDate(DateTime.parse(mapa['data_aprovacao'])); return mapa; }).toList();
        if (mounted) setState(() => _carregandoMoradores = false);
      }

      _novosAprovadosSub?.cancel();
      _novosAprovadosSub = FirebaseFirestore.instance.collection('usuarios')
        .where('sindico_vinculado', isEqualTo: widget.emailSindico)
        .where('perfil', isEqualTo: 'morador')
        .snapshots().listen((snap) {
          bool alterou = false;
          for (final change in snap.docChanges) {
            final data = change.doc.data()!..['id'] = change.doc.id; 
            final index = _moradoresCache.indexWhere((v) => v['id'] == change.doc.id);
            if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) { 
              if (index != -1) _moradoresCache[index] = data; 
              else _moradoresCache.insert(0, data); 
              alterou = true; 
            } else if (change.type == DocumentChangeType.removed) { 
              if (index != -1) { _moradoresCache.removeAt(index); alterou = true; } 
            }
          }
          if (alterou || _carregandoMoradores) { 
             if (mounted) setState(() => _carregandoMoradores = false); 
             _salvarCacheLocal(_moradoresCache); 
          }
      }, onError: (e) {
          debugPrint("Erro no stream de biometria: $e");
          if (mounted) setState(() => _carregandoMoradores = false);
      });
    } catch (e) { 
      if (mounted) setState(() => _carregandoMoradores = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) FirebaseAuth.instance.currentUser?.getIdToken(true); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _novosAprovadosSub?.cancel(); _scrollController.dispose(); _debounceBusca?.cancel(); super.dispose(); }

  Future<void> _capturarESalvarFoto(Map<String, dynamic> docMorador) async {
    Uint8List? bytesDaFoto;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) { bytesDaFoto = await showDialog<Uint8List>(context: context, barrierDismissible: false, builder: (ctx) => const DialogCapturaCamera(titulo: "Foto Biometria Facial")); } else {
      final source = await showDialog<ImageSource>(context: context, builder: (ctx) => AlertDialog(title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Origem da Foto")), content: const Text("Como deseja enviar a foto deste morador?"), actions:[TextButton.icon(icon: const Icon(Icons.folder), label: const Text("Arquivo / Galeria"), onPressed: () => Navigator.pop(ctx, ImageSource.gallery)), TextButton.icon(icon: const Icon(Icons.camera_alt), label: const Text("Tirar Foto (Câmera)"), onPressed: () => Navigator.pop(ctx, ImageSource.camera))]));
      if (source != null) try { final photo = await _picker.pickImage(source: source, maxWidth: 800, preferredCameraDevice: CameraDevice.front); if (photo != null) bytesDaFoto = await photo.readAsBytes(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao acessar câmera: $e"))); return; }
    }
    if (bytesDaFoto != null) {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Expanded(child: Text("Enviando foto segura para a nuvem..."))])));
      try {
        final path = "biometria/${widget.emailSindico}/${docMorador['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg", storageRef = FirebaseStorage.instance.ref().child(path);
        await storageRef.putData(bytesDaFoto, SettableMetadata(contentType: 'image/jpeg')); final downloadUrl = await storageRef.getDownloadURL();
        if (docMorador['foto_storage_url'] != null) try { await FirebaseStorage.instance.refFromURL(docMorador['foto_storage_url']).delete(); } catch (_) {}
        await FirebaseFirestore.instance.collection('usuarios').doc(docMorador['id']).update({'foto_storage_url': downloadUrl, 'foto_biometria': FieldValue.delete(), 'sincronizado_catraca': false});
        final idx = _moradoresCache.indexWhere((m) => m['id'] == docMorador['id']);
        if (idx != -1) { setState(() { _moradoresCache[idx]['foto_storage_url'] = downloadUrl; _moradoresCache[idx].remove('foto_biometria'); _moradoresCache[idx]['sincronizado_catraca'] = false; }); _salvarCacheLocal(_moradoresCache); }
        if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto salva no servidor. Lembre-se de clicar em Sincronizar!"), backgroundColor: Colors.green)); }
      } catch (e) { if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e), style: TextStyle(color: Theme.of(context).colorScheme.onError)), backgroundColor: Theme.of(context).colorScheme.error)); } }
    }
  }

  Future<void> _sincronizarComEquipamentos(Map<String, dynamic> docMorador, String fotoUrl) async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const AlertDialog(content: Row(children:[CircularProgressIndicator(), SizedBox(width: 20), Expanded(child: Text("Sincronizando pela rede local com as catracas faciais..."))])));
    try {
      final responseImg = await http.get(Uri.parse(fotoUrl)); if (responseImg.statusCode != 200) throw Exception("Falha ao baixar imagem do servidor.");
      final base64Image = base64Encode(responseImg.bodyBytes), snapFaces = await FirebaseFirestore.instance.collection('idfaces').where('sindico_vinculado', isEqualTo: widget.emailSindico).get();
      if (snapFaces.docs.isEmpty) { if (!mounted) return; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nenhuma catraca facial foi configurada pelo técnico ainda."), backgroundColor: Colors.orange)); return; }
      int sucesso = 0, falha = 0;
      for (final catraca in snapFaces.docs) {
        final cData = catraca.data(); if (cData['marca'] != 'control_id') { falha++; continue; }
        try {
          final ipLocal = cData['ip_local'], responseLogin = await http.post(Uri.parse('http://$ipLocal/login.fcgi'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"login": cData['usuario'] ?? 'admin', "password": cData['senha_criptografada'] == true ? CryptoHelper.descriptografar(cData['senha'] ?? 'admin') : (cData['senha'] ?? 'admin')})).timeout(const Duration(seconds: 5));
          if (responseLogin.statusCode == 200) {
            final token = jsonDecode(responseLogin.body)['session'], idNumerico = docMorador['id'].hashCode.abs();
            await http.post(Uri.parse('http://$ipLocal/create_objects.fcgi?session=$token'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"object": "users", "values": [{"id": idNumerico, "name": docMorador['nome'], "registration": docMorador['id']}]}));
            if ((await http.post(Uri.parse('http://$ipLocal/user_set_image.fcgi?session=$token'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({"user_id": idNumerico, "image": base64Image, "timestamp": DateTime.now().millisecondsSinceEpoch ~/ 1000})).timeout(const Duration(seconds: 15))).statusCode == 200) sucesso++; else falha++;
          } else falha++;
        } catch (_) { falha++; }
      }
      if (sucesso > 0) {
        await FirebaseFirestore.instance.collection('usuarios').doc(docMorador['id']).update({'sincronizado_catraca': true});
        final idx = _moradoresCache.indexWhere((m) => m['id'] == docMorador['id']);
        if (idx != -1) { setState(() => _moradoresCache[idx]['sincronizado_catraca'] = true); _salvarCacheLocal(_moradoresCache); }
        if (!mounted) return; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sincronizado com sucesso em $sucesso equipamento(s)! ($falha falhas)"), backgroundColor: Colors.green));
      } else { if (!mounted) return; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Erro ao sincronizar. Verifique se o computador está na mesma rede dos aparelhos.", style: TextStyle(color: Colors.white)), backgroundColor: Theme.of(context).colorScheme.error)); }
    } catch (e) { if (!mounted) return; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Theme.of(context).colorScheme.error)); }
  }

  void _removerFoto(Map<String, dynamic> doc) {
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: Text("Excluir Biometria Facial", style: TextStyle(color: colorScheme.error)), content: const Text("Deseja apagar a foto deste morador? (Será necessário excluir manualmente na catraca depois)."), actions:[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError), onPressed: () async {
        try { if (doc['foto_storage_url']?.toString().startsWith('http') == true) await FirebaseStorage.instance.refFromURL(doc['foto_storage_url']).delete(); } catch(_) {}
        await FirebaseFirestore.instance.collection('usuarios').doc(doc['id']).update({'foto_biometria': FieldValue.delete(), 'foto_storage_url': FieldValue.delete(), 'sincronizado_catraca': FieldValue.delete()});
        final idx = _moradoresCache.indexWhere((m) => m['id'] == doc['id']);
        if (idx != -1) { setState(() { _moradoresCache[idx].remove('foto_biometria'); _moradoresCache[idx].remove('foto_storage_url'); _moradoresCache[idx].remove('sincronizado_catraca'); }); _salvarCacheLocal(_moradoresCache); }
        if (mounted) Navigator.pop(ctx);
      }, child: const Text("EXCLUIR FOTO"))]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(children:[
      Padding(padding: const EdgeInsets.all(16.0), child: Row(children:[Icon(Icons.face, size: 40, color: colorScheme.primary), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[const FittedBox(fit: BoxFit.scaleDown, child: Text("Central Biometria Facial", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, child: Text("Capture e envie as fotos dos moradores direto para a catraca local.", style: TextStyle(color: colorScheme.onSurfaceVariant)))]))])),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: TextField(onChanged: _aoDigitarBusca, decoration: InputDecoration(labelText: "Buscar Morador (Nome ou Bloco-AP. Ex: 10-12)", prefixIcon: const Icon(Icons.search), suffixIcon: _buscandoNuvem ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2)) : null, border: const OutlineInputBorder()))), const SizedBox(height: 10),
      Expanded(child: _carregandoMoradores ? const Center(child: CircularProgressIndicator()) : Builder(builder: (context) {
        final moradores = _moradoresCache.where((data) { if (data['status'] != 'aprovado') return false; final nome = (data['nome'] ?? '').toString().toLowerCase(), bloco = (data['bloco'] ?? '').toString().toLowerCase(), ap = (data['ap'] ?? '').toString().toLowerCase(); return nome.contains(busca) || bloco.contains(busca) || ap.contains(busca) || "$bloco-$ap".contains(busca.replaceAll(' ', '')); }).toList(), listaPaginada = moradores.take(_limiteVisivel).toList();
        if (listaPaginada.isEmpty) return _buscandoNuvem ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 15), Text("Sincronizando com a Nuvem...")])) : const Center(child: Text("Nenhum morador encontrado."));
        return ListView.builder(controller: _scrollController, padding: const EdgeInsets.all(16), itemCount: listaPaginada.length + (_buscandoNuvem ? 1 : 0), itemBuilder: (context, index) {
          if (index == listaPaginada.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Buscando mais antigos na nuvem...", style: TextStyle(color: Colors.grey))])));
          final data = listaPaginada[index], temFoto = data['foto_storage_url'] != null, sincronizado = data['sincronizado_catraca'] == true;
          return Card(elevation: 2, margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(12.0), child: Wrap(spacing: 15, crossAxisAlignment: WrapCrossAlignment.center, children:[Container(width: 80, height: 80, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), clipBehavior: Clip.antiAlias, child: temFoto ? Image.network(data['foto_storage_url'], fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey)) : Icon(Icons.person, size: 50, color: colorScheme.onSurfaceVariant)), SizedBox(width: 180, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("B: ${data['bloco']} | AP: ${data['ap']}", style: TextStyle(color: colorScheme.onSurfaceVariant))), const SizedBox(height: 5), if (!temFoto) const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("🔴 Nenhuma foto cadastrada", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))) else if (!sincronizado) const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("🟡 Foto pendente de envio para catraca", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))) else const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("🟢 Ativo na Catraca", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)))])), Column(key: index == 0 ? keyTutBioSync : null, crossAxisAlignment: CrossAxisAlignment.end, children:[FittedBox(fit: BoxFit.scaleDown, child: ElevatedButton.icon(key: index == 0 ? keyTutBioFoto : null, style: ElevatedButton.styleFrom(backgroundColor: temFoto ? colorScheme.secondaryContainer : colorScheme.primary, foregroundColor: temFoto ? colorScheme.onSecondaryContainer : colorScheme.onPrimary), icon: Icon(temFoto ? Icons.replay : Icons.camera_alt, size: 16), label: Text(temFoto ? "Refazer Foto" : "Enviar Foto"), onPressed: () => _capturarESalvarFoto(data))), if (temFoto) ...[const SizedBox(height: 5), Row(mainAxisSize: MainAxisSize.min, children:[FittedBox(fit: BoxFit.scaleDown, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), icon: const Icon(Icons.sync, size: 16), label: const Text("Sincronizar"), onPressed: () => _sincronizarComEquipamentos(data, data['foto_storage_url']))), const SizedBox(width: 5), IconButton(icon: Icon(Icons.delete, color: colorScheme.error), tooltip: "Apagar", onPressed: () => _removerFoto(data))])]])])));
        });
      }))
    ]);
  }
}

class TelaVisitantes extends StatefulWidget {
  final String emailSindico, perfil;
  const TelaVisitantes({super.key, required this.emailSindico, required this.perfil});
  @override
  State<TelaVisitantes> createState() => _TelaVisitantesState();
}

class _TelaVisitantesState extends State<TelaVisitantes> with WidgetsBindingObserver {
  String busca = "", filtroStatus = "all"; DateTime? _dataFiltroInicio, _dataFiltroFim; int _diasHistorico = 30;
  late Stream<QuerySnapshot> _esperandoDeliveryStream;
  List<Map<String, dynamic>> _visitantesCache = [];
  bool _carregandoVisitantes = true, _buscandoNuvem = false, _fimDoHistorico = false;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<QuerySnapshot>? _visitantesAtivosSub;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _scrollController.addListener(_aoRolarTela); _initStreams(); _carregarVisitantesDeltaSync(); }

  void _aoRolarTela() { if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_buscandoNuvem && !_fimDoHistorico && _visitantesCache.isNotEmpty && busca.isEmpty && _dataFiltroInicio == null && filtroStatus == "all") _buscarMaisAntigosNaNuvem(); }

  Future<void> _buscarMaisAntigosNaNuvem() async {
    setState(() => _buscandoNuvem = true);
    try {
      setState(() { _diasHistorico += 30; });
      final limiteTs = Timestamp.fromDate(DateTime.now().subtract(Duration(days: _diasHistorico))), dataMaisVelha = _visitantesCache.isNotEmpty ? _visitantesCache.last['entrada'] as Timestamp? : null;
      if (dataMaisVelha != null) {
        final snapVelhos = await FirebaseFirestore.instance.collection('visitantes').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('entrada', isGreaterThanOrEqualTo: limiteTs).where('entrada', isLessThan: dataMaisVelha).orderBy('entrada', descending: true).get();
        if (snapVelhos.docs.isNotEmpty) { for (var doc in snapVelhos.docs) _visitantesCache.add(doc.data()..['id'] = doc.id); _visitantesCache.sort((a, b) => (b['entrada'] as Timestamp).compareTo(a['entrada'] as Timestamp)); if (mounted) setState(() {}); await _salvarCacheLocal(_visitantesCache); } else _fimDoHistorico = true;
      }
    } catch (_) {}
    if (mounted) setState(() => _buscandoNuvem = false);
  }

  Future<void> _salvarCacheLocal(List<Map<String, dynamic>> lista) async {
    try {
      final jsonStr = jsonEncode(lista.map((item) => item.map((key, value) => MapEntry(key, value is Timestamp ? value.toDate().toIso8601String() : value))).toList());
      if (kIsWeb) await (await SharedPreferences.getInstance()).setString('visitas_delta_${widget.emailSindico}', jsonStr);
      else await File('${(await getApplicationDocumentsDirectory()).path}/visitas_delta_${widget.emailSindico}.json').writeAsString(jsonStr);
    } catch (_) {}
  }

  Future<void> _carregarVisitantesDeltaSync() async {
    try {
      String jsonString = "";
      if (kIsWeb) jsonString = (await SharedPreferences.getInstance()).getString('visitas_delta_${widget.emailSindico}') ?? "";
      else { final file = File('${(await getApplicationDocumentsDirectory()).path}/visitas_delta_${widget.emailSindico}.json'); if (await file.exists()) jsonString = await file.readAsString(); }
      
      if (jsonString.isNotEmpty) {
        _visitantesCache = (jsonDecode(jsonString) as List).map((item) { final mapa = Map<String, dynamic>.from(item); if (mapa['entrada'] != null) mapa['entrada'] = Timestamp.fromDate(DateTime.parse(mapa['entrada'])); if (mapa['saida'] != null) mapa['saida'] = Timestamp.fromDate(DateTime.parse(mapa['saida'])); return mapa; }).toList();
      }
      if (mounted) setState(() => _carregandoVisitantes = false);

      Timestamp? ultimaData;
      if (_visitantesCache.isNotEmpty) { _visitantesCache.sort((a, b) => (b['entrada'] as Timestamp).compareTo(a['entrada'] as Timestamp)); ultimaData = _visitantesCache.first['entrada'] as Timestamp; } else ultimaData = Timestamp.fromDate(DateTime.now().subtract(Duration(days: _diasHistorico)));

      final snapNovos = await FirebaseFirestore.instance.collection('visitantes').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('entrada', isGreaterThan: ultimaData).orderBy('entrada', descending: true).get();
      if (snapNovos.docs.isNotEmpty) { for (var doc in snapNovos.docs) _visitantesCache.insert(0, doc.data()..['id'] = doc.id); _visitantesCache.sort((a, b) => (b['entrada'] as Timestamp).compareTo(a['entrada'] as Timestamp)); if (mounted) setState(() {}); await _salvarCacheLocal(_visitantesCache); }

      _visitantesAtivosSub?.cancel();
      _visitantesAtivosSub = FirebaseFirestore.instance.collection('visitantes').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('entrada', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 2)))).snapshots().listen((snap) {
        bool alterou = false;
        for (var change in snap.docChanges) {
          final data = change.doc.data()!..['id'] = change.doc.id; final index = _visitantesCache.indexWhere((v) => v['id'] == change.doc.id);
          if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) { if (index != -1) _visitantesCache[index] = data; else _visitantesCache.insert(0, data); alterou = true; } else if (change.type == DocumentChangeType.removed && index != -1) { _visitantesCache.removeAt(index); alterou = true; }
        }
        if (alterou) { _visitantesCache.sort((a, b) => (b['entrada'] as Timestamp).compareTo(a['entrada'] as Timestamp)); if (mounted) setState(() {}); _salvarCacheLocal(_visitantesCache); }
      });
    } catch (_) { if (mounted) setState(() => _carregandoVisitantes = false); }
  }

  void _initStreams() { _esperandoDeliveryStream = FirebaseFirestore.instance.collection('esperando_delivery').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) FirebaseAuth.instance.currentUser?.getIdToken(true); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _scrollController.dispose(); _visitantesAtivosSub?.cancel(); super.dispose(); }

  Future<void> _selecionarDataFiltro(BuildContext context) async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now(), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme), child: child!));
    if (picked != null) setState(() { _dataFiltroInicio = picked.start; _dataFiltroFim = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59); });
  }

  void _mostrarFotoExpandida(String urlFoto) => showDialog(context: context, builder: (ctx) => Dialog(backgroundColor: Colors.transparent, child: Stack(alignment: Alignment.center, children: [InteractiveViewer(panEnabled: true, minScale: 0.5, maxScale: 4, child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: urlFoto.startsWith('http') ? NetworkImage(urlFoto) : const AssetImage('assets/logo.png'), fit: BoxFit.contain)))), Positioned(top: 10, right: 10, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(ctx)))])));

  void _mostrarFormulario({Map<String, dynamic>? doc, Map<String, dynamic>? dadosOcr, Uint8List? fotoOcrBytes}) {
    final docC = TextEditingController(text: doc?['documento'] ?? dadosOcr?['documento'] ?? ''), nomeC = TextEditingController(text: doc?['nome'] ?? dadosOcr?['nome'] ?? '');
    String tipo = doc != null ? doc['tipo'] : 'visita';
    final destC = TextEditingController(text: doc?['destino'] ?? ''), veicC = TextEditingController(text: doc?['veiculo'] ?? ''), placaC = TextEditingController(text: doc?['placa'] ?? ''), obsC = TextEditingController(text: doc?['observacao'] ?? '');
    bool fotoAnexada = fotoOcrBytes != null, buscandoDados = false, salvandoRegistro = false;
    Uint8List? fotoLocal = fotoOcrBytes;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      
      Future<void> capturarFoto() async {
        try {
          Uint8List? b;
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) b = await showDialog<Uint8List>(context: context, barrierDismissible: false, builder: (ctxCam) => const DialogCapturaCamera(titulo: "Capturar Foto/Documento"));
          else { final photo = await _picker.pickImage(source: ImageSource.camera, maxWidth: 800); if (photo != null) b = await photo.readAsBytes(); }
          if (b != null) { setStateSB(() { fotoLocal = b; fotoAnexada = true; }); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto anexada com sucesso!"))); }
        } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao acessar câmera: $e"))); }
      }

      Future<void> buscarVisitanteExistente() async {
        if (docC.text.trim().isEmpty) return;
        setStateSB(() => buscandoDados = true);
        final snap = await FirebaseFirestore.instance.collection('visitantes').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('documento', isEqualTo: docC.text.trim().toUpperCase()).get();
        if (!mounted) return;
        if (snap.docs.isNotEmpty) {
          final docs = snap.docs.toList()..sort((a, b) => ((b.data() as Map)['entrada'] ?? Timestamp.now()).compareTo(((a.data() as Map)['entrada'] ?? Timestamp.now())));
          final lastData = docs.first.data() as Map;
          setStateSB(() { nomeC.text = lastData['nome'] ?? ''; veicC.text = lastData['veiculo'] ?? ''; placaC.text = lastData['placa'] ?? ''; destC.text = lastData['destino'] ?? ''; tipo = lastData['tipo'] ?? 'visita'; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dados encontrados e preenchidos!")));
        }
        setStateSB(() => buscandoDados = false);
      }

      return AlertDialog(
        title: FittedBox(fit: BoxFit.scaleDown, child: Text(doc == null ? "Registrar Entrada" : "Editar Visitante")),
        content: SizedBox(width: 550, child: SingleChildScrollView(child: Wrap(spacing: 20, runSpacing: 20, crossAxisAlignment: WrapCrossAlignment.start, children:[
          Column(children:[
            InkWell(onTap: salvandoRegistro ? null : capturarFoto, child: Container(width: 150, height: 150, decoration: BoxDecoration(color: fotoAnexada ? Colors.green.withValues(alpha:0.1) : colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10), border: Border.all(color: fotoAnexada ? Colors.green : colorScheme.outline), image: fotoLocal != null ? DecorationImage(image: MemoryImage(fotoLocal!), fit: BoxFit.cover) : null), child: fotoLocal == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.camera_alt, size: 40, color: colorScheme.onSurfaceVariant), const SizedBox(height: 5), Text("Tirar Foto", style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))]) : null)),
            if (fotoLocal != null) TextButton.icon(icon: const Icon(Icons.refresh, size: 14), label: const Text("Refazer Foto", style: TextStyle(fontSize: 12)), onPressed: salvandoRegistro ? null : capturarFoto)
          ]),
          SizedBox(width: 300, child: Column(mainAxisSize: MainAxisSize.min, children:[
            TextField(controller: docC, enabled: !salvandoRegistro, decoration: InputDecoration(labelText: "Documento (RG/CPF) *", suffixIcon: IconButton(icon: buscandoDados ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.search, color: colorScheme.primary), onPressed: salvandoRegistro ? null : buscarVisitanteExistente), filled: true, fillColor: colorScheme.primary.withValues(alpha:0.05)), onSubmitted: (_) => salvandoRegistro ? null : buscarVisitanteExistente()), const SizedBox(height: 10),
            TextField(controller: nomeC, enabled: !salvandoRegistro, decoration: const InputDecoration(labelText: "Nome Completo *"), inputFormatters: [UpperCaseTextFormatter()]),
            DropdownButtonFormField<String>(isExpanded: true, initialValue: tipo, items: const[DropdownMenuItem(value: 'visita', child: Text("Visita")), DropdownMenuItem(value: 'prestador', child: Text("Prestador de Serviço")), DropdownMenuItem(value: 'entregador', child: Text("Entregador")), DropdownMenuItem(value: 'outros', child: Text("Outros"))], onChanged: salvandoRegistro ? null : (v) => setStateSB(() => tipo = v!), decoration: const InputDecoration(labelText: "Tipo de Visita *")),
            TextField(controller: destC, enabled: !salvandoRegistro, decoration: const InputDecoration(labelText: "Destino (Bloco/AP) *")),
            Row(children:[Expanded(child: TextField(controller: veicC, enabled: !salvandoRegistro, decoration: const InputDecoration(labelText: "Veículo (Opcional)"), inputFormatters: [UpperCaseTextFormatter()])), const SizedBox(width: 10), Expanded(child: TextField(controller: placaC, enabled: !salvandoRegistro, decoration: const InputDecoration(labelText: "Placa (Opcional)"), inputFormatters:[UpperCaseTextFormatter()]))]),
            TextField(controller: obsC, enabled: !salvandoRegistro, decoration: const InputDecoration(labelText: "Observações"), maxLines: 2),
          ]))
        ]))),
        actions:[
          if (!salvandoRegistro) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: salvandoRegistro ? Colors.grey : Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
            onPressed: salvandoRegistro ? null : () async {
              if (nomeC.text.isEmpty || docC.text.isEmpty || destC.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha Documento, Nome e Destino."))); return; }
              setStateSB(() => salvandoRegistro = true);
              try {
                String urlStorage = "";
                if (fotoLocal != null) {
                  final token = FirebaseAuth.instance.currentUser != null ? await FirebaseAuth.instance.currentUser!.getIdToken(true) : '';
                  final response = await http.post(Uri.parse('https://salvarfotovisitante-hhygy7dtpa-uc.a.run.app'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({'data': {'image': base64Encode(fotoLocal!), 'sindico': widget.emailSindico, 'documento': docC.text.replaceAll(RegExp(r'[^0-9A-Za-z]'), '')}}));
                  if (response.statusCode == 200) {
                    final responseData = jsonDecode(response.body)['result'] ?? jsonDecode(response.body)['data'];
                    if (responseData != null && responseData['sucesso'] == true) urlStorage = responseData['url']; else throw Exception(responseData?['erro'] ?? "Falha ao salvar a foto na nuvem.");
                  } else {
                    String err = response.body; try { final j = jsonDecode(response.body); if (j['error'] != null) err = j['error']['message'] ?? err; } catch(_) {} throw Exception("O servidor rejeitou a foto (${response.statusCode}): $err");
                  }
                }
                final data = <String, dynamic>{'nome': nomeC.text.toUpperCase(), 'documento': docC.text.toUpperCase(), 'tipo': tipo, 'destino': destC.text, 'veiculo': veicC.text.toUpperCase(), 'placa': placaC.text.toUpperCase(), 'observacao': obsC.text, 'sindico_vinculado': widget.emailSindico, 'operador_registro': operadorLogado, if (urlStorage.isNotEmpty) 'foto_doc_url': urlStorage};
                if (doc == null) {
                  data['entrada'] = FieldValue.serverTimestamp(); data['saida'] = null;
                  await FirebaseFirestore.instance.collection('visitantes').add(data);
                  await registrarAuditoria(widget.emailSindico, "Entrada de Visitante", "Visitantes", "${nomeC.text.toUpperCase()} para ${destC.text}");
                  try {
                    final destinoUpper = destC.text.toUpperCase(), pedacos = destinoUpper.replaceAll(RegExp(r'[^A-Z0-9]'), ' ').split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
                    final moradoresSnap = await FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('perfil', isEqualTo: 'morador').get();
                    for (final m in moradoresSnap.docs) {
                      final blocoM = (m.data()['bloco'] ?? '').toString().toUpperCase(), apM = (m.data()['ap'] ?? '').toString().toUpperCase();
                      if (apM.isEmpty) continue;
                      if ((pedacos.contains(apM) || destinoUpper.contains(apM)) && (blocoM.isEmpty || pedacos.contains(blocoM) || destinoUpper.contains("BLOCO $blocoM") || destinoUpper.contains("BL $blocoM"))) {
                        await FirebaseFirestore.instance.collection('notificacoes').add({'sindico_vinculado': widget.emailSindico, 'para': (m.data()['email'] ?? m.id).toString().toLowerCase().trim(), 'nome_destino': 'Bloco ${m.data()['bloco']} AP ${m.data()['ap']} - ${m.data()['nome']}', 'titulo': '🚶 VISITA LIBERADA', 'mensagem': "${nomeC.text.toUpperCase()} passou pela portaria e está a caminho do seu apartamento.", 'data': FieldValue.serverTimestamp(), 'remetente': 'Portaria', 'tipo_acao': 'acao_avisos'});
                      }
                    }
                  } catch (_) {}
                } else {
                  await FirebaseFirestore.instance.collection('visitantes').doc(doc['id']).update(data);
                }
                if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entrada registrada com sucesso!"), backgroundColor: Colors.green)); }
              } catch (e) { if (mounted) { setStateSB(() => salvandoRegistro = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); } }
            },
            child: salvandoRegistro ? const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)), SizedBox(width: 10), Text("SALVANDO...")]) : const Text("SALVAR E LIBERAR")
          )
        ],
      );
    }));
  }

  static Uint8List _juntarImagensIsolate(Map<String, Uint8List> data) {
    final frente = img.decodeImage(data['frente']!)!, verso = img.decodeImage(data['verso']!)!;
    final merged = img.Image(width: frente.width > verso.width ? frente.width : verso.width, height: frente.height + verso.height);
    img.compositeImage(merged, frente, dstX: 0, dstY: 0); img.compositeImage(merged, verso, dstX: 0, dstY: frente.height);
    return img.encodeJpg(merged, quality: 85);
  }

  Future<Uint8List?> _capturarUmaFoto(String titulo) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) return await showDialog<Uint8List>(context: context, barrierDismissible: false, builder: (ctx) => DialogCapturaCamera(titulo: titulo));
    try { final photo = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1000); if (photo != null) return await photo.readAsBytes(); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao acessar câmera nativa: $e"))); }
    return null;
  }

  void _iniciarCapturaUrna() async {
    final colorScheme = Theme.of(context).colorScheme;
    final bytesFrente = await _capturarUmaFoto("1. Capturar FRENTE do Documento"); if (bytesFrente == null) return;
    final querVerso = await showDialog<bool>(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(title: const Row(children: [Icon(Icons.flip, color: Colors.blue), SizedBox(width: 10), Text("Frente Capturada!")]), content: const Text("Este documento possui informações no verso (Ex: RG, CNH)?\n\nJuntar as duas partes ajuda a Inteligência Artificial a achar o Nome e o Número de uma vez só."), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("NÃO, SÓ A FRENTE", style: TextStyle(color: Colors.grey))), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), icon: const Icon(Icons.cameraswitch), label: const Text("SIM, LER O VERSO"), onPressed: () => Navigator.pop(ctx, true))])) ?? false;
    Uint8List bytesFinais = bytesFrente;
    if (querVerso) {
      showDialog(context: context, barrierDismissible: false, builder: (c) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Expanded(child: Text("Preparando a câmera para o verso..."))])));
      await Future.delayed(const Duration(milliseconds: 1500)); if (mounted) Navigator.pop(context);
      final bytesVerso = await _capturarUmaFoto("2. Capturar VERSO do Documento");
      if (bytesVerso != null) {
        showDialog(context: context, barrierDismissible: false, builder: (c) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Expanded(child: Text("Unindo a frente e o verso da imagem..."))])));
        try { bytesFinais = await compute(_juntarImagensIsolate, {'frente': bytesFrente, 'verso': bytesVerso}); } catch (_) {}
        if (mounted) Navigator.pop(context);
      }
    }
    showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 20), Expanded(child: Text("A Inteligência Artificial está lendo o documento...", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)))])));
    try {
      final resultadoOcr = await HelperOCR.extrairDadosDocumento(bytesFinais);
      if (mounted) { Navigator.pop(context); _mostrarFormulario(dadosOcr: resultadoOcr, fotoOcrBytes: bytesFinais); }
    } catch (e) { if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e), style: TextStyle(color: colorScheme.onError)), backgroundColor: colorScheme.error)); } }
  }

  void _validarCodigoVip() {
    String codigoDigitado = "";
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Validar PIN VIP da Visita")),
        content: Column(mainAxisSize: MainAxisSize.min, children:[const Text("Digite os números gerados pela visita no auto-cadastro:", style: TextStyle(color: Colors.grey)), const SizedBox(height: 15), TextField(onChanged: (v) => codigoDigitado = v.trim(), decoration: InputDecoration(labelText: kIsWeb || defaultTargetPlatform == TargetPlatform.windows ? "PIN (Leitor ou Teclado)" : "PIN VIP", border: const OutlineInputBorder()), keyboardType: TextInputType.number, maxLength: 6, autofocus: kIsWeb || defaultTargetPlatform == TargetPlatform.windows, style: const TextStyle(fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold), textAlign: TextAlign.center)]),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: colorScheme.onSecondary), onPressed: () async {
            if (codigoDigitado.isEmpty || codigoDigitado.length < 4) return;
            final snap = await FirebaseFirestore.instance.collection('acessos_vip').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('codigo', isEqualTo: codigoDigitado).where('status', isEqualTo: 'valido').get();
            if (!mounted) return; Navigator.pop(ctx);
            if (snap.docs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("PIN Inválido, já utilizado ou não encontrado!", style: TextStyle(color: Colors.white)), backgroundColor: colorScheme.error)); return; }
            final docVip = snap.docs.first, dataVip = docVip.data() as Map<String, dynamic>;
            if (dataVip['data_criacao'] != null && DateTime.now().isAfter((dataVip['data_criacao'] as Timestamp).toDate().add(const Duration(hours: 24)))) {
               await docVip.reference.update({'status': 'expirado'});
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Este PIN expirou! Já se passaram mais de 24h desde a geração.", style: TextStyle(color: Colors.white)), backgroundColor: colorScheme.error)); return;
            }
            _confirmarEntradaVip(docVip.reference, dataVip);
          }, child: const Text("PROCURAR"))
        ]
      );
    });
  }

  void _confirmarEntradaVip(DocumentReference refVip, Map<String, dynamic> dataVip) {
    final veiculo = dataVip['usa_veiculo'] ?? false, fotoCaminhoOuUrl = dataVip['foto_doc_url'] ?? '', vaga = dataVip['vaga'] ?? '';
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children:[Icon(Icons.star, color: colorScheme.secondary), const FittedBox(fit: BoxFit.scaleDown, child: Text("Acesso VIP Liberado"))]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[
          if (fotoCaminhoOuUrl.isNotEmpty) ...[Center(child: InkWell(onTap: () async { _mostrarFotoExpandida(fotoCaminhoOuUrl.startsWith('http') ? fotoCaminhoOuUrl : await FirebaseStorage.instance.ref().child(fotoCaminhoOuUrl).getDownloadURL()); }, child: Container(height: 180, width: double.infinity, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10), border: Border.all(color: colorScheme.outlineVariant)), clipBehavior: Clip.antiAlias, child: FutureBuilder<String>(future: fotoCaminhoOuUrl.startsWith('http') ? Future.value(fotoCaminhoOuUrl) : FirebaseStorage.instance.ref().child(fotoCaminhoOuUrl).getDownloadURL(), builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator()); if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.broken_image, color: Colors.grey, size: 40), Text("Erro ao carregar foto", style: TextStyle(color: Colors.grey, fontSize: 12))])); return Image.network(snapshot.data!, fit: BoxFit.cover); })))), const SizedBox(height: 15)] else ...[Center(child: Container(height: 100, width: double.infinity, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.badge, color: Colors.grey, size: 40), Text("Visitante sem foto do documento", style: TextStyle(color: Colors.grey, fontSize: 12))]))), const SizedBox(height: 15)],
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Visitante: ${dataVip['nome_visitante']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Documento: ${dataVip['documento']}", style: const TextStyle(fontSize: 16))), const SizedBox(height: 10), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Vai para o Bloco ${dataVip['bloco']} / AP ${dataVip['ap']}", style: TextStyle(fontSize: 16, color: colorScheme.primary, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Autorizado por: ${dataVip['morador_autorizou']}", style: const TextStyle(fontSize: 14))), const Divider(),
          if (veiculo) ...[const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("🚗 Entrada com Veículo", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Modelo: ${dataVip['modelo_cor']}")), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Placa: ${dataVip['placa']}", style: const TextStyle(fontWeight: FontWeight.bold))), if (vaga.isNotEmpty) FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Vaga Autorizada: $vaga", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)))] else const FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("🚶 Entrada a Pé", style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(height: 15), const Text("Confirme a liberação da catraca/portão após conferir a foto.", style: TextStyle(color: Colors.grey))
        ])),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () async {
            try {
              final batch = FirebaseFirestore.instance.batch();
              batch.update(refVip, {'status': 'utilizado', 'data_utilizacao': FieldValue.serverTimestamp()});
              batch.set(FirebaseFirestore.instance.collection('visitantes').doc(), {'sindico_vinculado': widget.emailSindico, 'nome': dataVip['nome_visitante'], 'documento': dataVip['documento'], 'tipo': 'visita', 'destino': "Bloco ${dataVip['bloco']} / AP ${dataVip['ap']}", 'veiculo': veiculo ? dataVip['modelo_cor'] : '', 'placa': veiculo ? dataVip['placa'] : '', 'observacao': 'Auto-cadastro VIP via Link (Morador: ${dataVip['morador_autorizou']})${veiculo && vaga.isNotEmpty ? ' | Vaga: $vaga' : ''}', 'entrada': FieldValue.serverTimestamp(), 'saida': null, 'operador_registro': operadorLogado, 'foto_doc_url': fotoCaminhoOuUrl});
              final moradoresSnap = await FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('perfil', isEqualTo: 'morador').where('bloco', isEqualTo: dataVip['bloco']).where('ap', isEqualTo: dataVip['ap']).get();
              for (var docM in moradoresSnap.docs) batch.set(FirebaseFirestore.instance.collection('notificacoes').doc(), {'sindico_vinculado': widget.emailSindico, 'para': (docM.data()['email'] ?? docM.id).toString().toLowerCase().trim(), 'nome_destino': 'Bloco ${docM.data()['bloco']} AP ${docM.data()['ap']} - ${docM.data()['nome']}', 'titulo': '🚶 VISITA LIBERADA (VIP)', 'mensagem': "${dataVip['nome_visitante']} acessou a portaria e está a caminho do seu apartamento.", 'data': FieldValue.serverTimestamp(), 'remetente': 'Portaria Automática', 'tipo_acao': 'acao_avisos'});
              await batch.commit(); await registrarAuditoria(widget.emailSindico, "Entrada VIP Liberada", "Visitantes", "${dataVip['nome_visitante']} acessou usando PIN.");
              if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Acesso Registrado! O morador foi notificado no celular."), backgroundColor: Colors.green)); }
            } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); }
          }, child: const Text("LIBERAR ENTRADA"))
        ]
      );
    });
  }

  String _formatarData(DateTime d) => DateFormat('dd/MM HH:mm').format(d);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(children:[
      StreamBuilder<QuerySnapshot>(stream: _esperandoDeliveryStream, builder: (context, snapDelivery) {
        if (snapDelivery.hasError || !snapDelivery.hasData || snapDelivery.data!.docs.isEmpty) return const SizedBox.shrink();
        return Container(margin: const EdgeInsets.only(top: 10, left: 16, right: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: colorScheme.surface.withValues(alpha:0.8), border: Border.all(color: colorScheme.primary, width: 1.5), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.fastfood, color: colorScheme.primary), const SizedBox(width: 10), Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Aguardando Delivery na Portaria", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16))))]), const Divider(color: Colors.white24),
          SizedBox(height: 60, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: snapDelivery.data!.docs.length, itemBuilder: (ctx, i) {
            final docLanche = snapDelivery.data!.docs[i], dataLanche = docLanche.data() as Map<String, dynamic>, desc = dataLanche['descricao'] ?? 'Delivery Rápido', nomeAp = "${dataLanche['nome']} (B:${dataLanche['bloco']} A:${dataLanche['ap']})";
            return Padding(padding: const EdgeInsets.only(right: 10), child: LogicNeonButton(corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: () async {
               showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Notificar Morador"), content: Text("O entregador do(a) $desc para $nomeAp chegou?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () async {
                 Navigator.pop(ctx);
                 try { await FirebaseFirestore.instance.collection('notificacoes').add({'sindico_vinculado': widget.emailSindico, 'para': dataLanche['email'] ?? '', 'nome_destino': 'Bloco ${dataLanche['bloco']} AP ${dataLanche['ap']} - ${dataLanche['nome']}', 'titulo': '🍔 O ENTREGADOR CHEGOU!', 'mensagem': 'A sua entrega ($desc) já está na portaria te esperando. Por favor, desça para retirar.', 'data': FieldValue.serverTimestamp(), 'remetente': operadorLogado, 'tipo_acao': 'acao_avisos', 'ocultar_do_historico': true}); await docLanche.reference.delete(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Morador notificado via App!"), backgroundColor: Colors.green)); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao notificar: $e"), backgroundColor: Colors.red)); }
               }, child: const Text("SIM, AVISAR"))]));
            }, child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.notifications_active, color: Colors.white, size: 18), const SizedBox(width: 8), Text("AP ${dataLanche['ap']} - $desc", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])));
          }))
        ]));
      }),
      Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 15, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children:[
        if (widget.perfil == 'porteiro') ...[
          ElevatedButton.icon(key: keyTutVisOcr, icon: const Icon(Icons.document_scanner), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("Registrar Entregador/Prestador (Câmera)")), style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15)), onPressed: _iniciarCapturaUrna),
          ElevatedButton.icon(key: keyTutVisManual, icon: const Icon(Icons.edit_document), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("Entrada Manual")), style: ElevatedButton.styleFrom(backgroundColor: colorScheme.surfaceContainerHighest, foregroundColor: colorScheme.onSurfaceVariant, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15)), onPressed: () => _mostrarFormulario()),
          ElevatedButton.icon(key: keyTutVisVip, icon: const Icon(Icons.star), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("Validar PIN (Auto-cadastro)")), style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: colorScheme.onSecondary, padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15)), onPressed: _validarCodigoVip),
        ],
        SizedBox(width: 250, child: TextField(key: keyTutVisBusca, onChanged: (v) => setState(() => busca = v.toLowerCase()), decoration: const InputDecoration(labelText: "Pesquisar", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: _dataFiltroInicio != null ? colorScheme.primary : colorScheme.surfaceContainerHighest, foregroundColor: _dataFiltroInicio != null ? colorScheme.onPrimary : colorScheme.onSurfaceVariant, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15)), icon: const Icon(Icons.calendar_month), label: FittedBox(fit: BoxFit.scaleDown, child: Text(_dataFiltroInicio != null ? "${DateFormat('dd/MM').format(_dataFiltroInicio!)} - ${DateFormat('dd/MM').format(_dataFiltroFim!)}" : "Filtrar Data")), onPressed: () => _selecionarDataFiltro(context)),
        if (_dataFiltroInicio != null) IconButton(icon: Icon(Icons.clear, color: colorScheme.error), onPressed: () => setState(() { _dataFiltroInicio = null; _dataFiltroFim = null; })),
        Container(key: keyTutVisFiltros, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(5)), child: DropdownButton<String>(underline: const SizedBox(), value: filtroStatus, items: const[DropdownMenuItem(value: "all", child: Text("Todos")), DropdownMenuItem(value: "present", child: Text("Presentes")), DropdownMenuItem(value: "left", child: Text("Já saíram"))], onChanged: (v) => setState(() => filtroStatus = v!)))
      ])),
      Expanded(child: _carregandoVisitantes ? const Center(child: CircularProgressIndicator()) : Builder(builder: (context) {
        final listaFiltrada = _visitantesCache.where((data) {
          final temSaida = data['saida'] != null;
          if (filtroStatus == "present" && temSaida) return false;
          if (filtroStatus == "left" && !temSaida) return false;
          if (_dataFiltroInicio != null && data['entrada'] != null) { final dtEnt = (data['entrada'] as Timestamp).toDate(); if (dtEnt.isBefore(_dataFiltroInicio!) || dtEnt.isAfter(_dataFiltroFim!)) return false; }
          final n = (data['nome'] ?? '').toString().toLowerCase(), doc = (data['documento'] ?? '').toString().toLowerCase(), dest = (data['destino'] ?? '').toString().toLowerCase();
          return n.contains(busca) || doc.contains(busca) || dest.contains(busca) || dest.replaceAll('bloco ', '').replaceAll(' / ap ', '-').replaceAll(' ', '').contains(busca.replaceAll(' ', ''));
        }).toList();
        if (listaFiltrada.isEmpty) return const Center(child: Text("Nenhum visitante encontrado neste período."));

        return ListView.builder(controller: _scrollController, itemCount: listaFiltrada.length + (_buscandoNuvem ? 1 : 0), itemBuilder: (context, index) {
          if (_buscandoNuvem && index == listaFiltrada.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Buscando mais antigos na nuvem...", style: TextStyle(color: Colors.grey))])));
          final data = listaFiltrada[index], temSaida = data['saida'] != null, urlFotoVisitante = data['foto_doc_url'] ?? '', entStr = data['entrada'] != null ? _formatarData((data['entrada'] as Timestamp).toDate()) : "...", saiStr = temSaida ? _formatarData((data['saida'] as Timestamp).toDate()) : "Ainda no local";
          return Card(margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: Padding(padding: const EdgeInsets.all(16.0), child: Wrap(spacing: 15, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.start, children:[
            InkWell(onTap: () async { if (urlFotoVisitante.isNotEmpty) _mostrarFotoExpandida(urlFotoVisitante.startsWith('http') ? urlFotoVisitante : await FirebaseStorage.instance.ref().child(urlFotoVisitante).getDownloadURL()); }, child: Container(width: 80, height: 100, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorScheme.outlineVariant)), clipBehavior: Clip.antiAlias, child: urlFotoVisitante.isNotEmpty ? FutureBuilder<String>(future: urlFotoVisitante.startsWith('http') ? Future.value(urlFotoVisitante) : FirebaseStorage.instance.ref().child(urlFotoVisitante).getDownloadURL(), builder: (context, snapshot) { if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))); if (snapshot.hasError || !snapshot.hasData) return Icon(Icons.broken_image, color: colorScheme.onSurfaceVariant); return Image.network(snapshot.data!, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: colorScheme.onSurfaceVariant)); }) : Icon(Icons.person, size: 50, color: colorScheme.onSurfaceVariant))),
            SizedBox(width: 400, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'].toString().toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), const Divider(), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("📄 Documento: ${data['documento']}", style: const TextStyle(fontSize: 15))), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("📍 Destino: ${data['destino']} (${data['tipo'].toString().toUpperCase()})", style: const TextStyle(fontSize: 15))), if (data['veiculo'] != null && data['veiculo'].toString().isNotEmpty) FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("🚗 Veículo: ${data['veiculo']} - Placa: ${data['placa']}", style: const TextStyle(fontSize: 15))), const SizedBox(height: 5), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Op. Registro: ${data['operador_registro'] ?? 'Desconhecido'}", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12))), const SizedBox(height: 10), Wrap(spacing: 10, runSpacing: 5, children:[Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withValues(alpha:0.2), borderRadius: BorderRadius.circular(4)), child: Text("Entrada: $entStr", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: temSaida ? colorScheme.errorContainer : Colors.orange.withValues(alpha:0.2), borderRadius: BorderRadius.circular(4)), child: Text("Saída: $saiStr", style: TextStyle(color: temSaida ? colorScheme.error : Colors.orange, fontWeight: FontWeight.bold)))])])),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children:[if (!temSaida && widget.perfil == 'porteiro') FittedBox(fit: BoxFit.scaleDown, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError), icon: const Icon(Icons.exit_to_app, size: 16), label: const Text("Registrar Saída"), onPressed: () async { await FirebaseFirestore.instance.collection('visitantes').doc(data['id']).update({'saida': FieldValue.serverTimestamp()}); setState(() => data['saida'] = Timestamp.now()); _salvarCacheLocal(_visitantesCache); await registrarAuditoria(widget.emailSindico, "Saída de Visitante", "Visitantes", "${data['nome']} registrou saída."); })), if (widget.perfil == 'sindico') ...[const SizedBox(height: 10), Row(mainAxisSize: MainAxisSize.min, children:[IconButton(icon: Icon(Icons.edit, color: colorScheme.primary), onPressed: () => _mostrarFormulario(doc: data), tooltip: "Editar"), IconButton(icon: Icon(Icons.delete, color: colorScheme.onSurfaceVariant), tooltip: "Excluir", onPressed: () async { await FirebaseFirestore.instance.collection('visitantes').doc(data['id']).delete(); setState(() => _visitantesCache.removeWhere((v) => v['id'] == data['id'])); _salvarCacheLocal(_visitantesCache); })])] ])
          ])));
        });
      }))
    ]);
  }
}

class TelaFormularioVIP extends StatefulWidget {
  final String tokenConvite;
  const TelaFormularioVIP({super.key, required this.tokenConvite});
  @override
  State<TelaFormularioVIP> createState() => _TelaFormularioVIPState();
}

class _TelaFormularioVIPState extends State<TelaFormularioVIP> {
  bool _carregando = true, _conviteValido = false, _vaiDeVeiculo = false, _fotoAnexada = false, _buscandoHistorico = false;
  Map<String, dynamic>? _dadosConvite;
  final _docCtrl = TextEditingController(), _nomeCtrl = TextEditingController(), _modeloCorCtrl = TextEditingController(), _placaCtrl = TextEditingController(), _vagaCtrl = TextEditingController();
  Uint8List? _fotoBytes; String _codigoGerado = "";
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() { super.initState(); _validarLink(); }

  Future<void> _validarLink() async {
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('validarLinkVip').call({'token': widget.tokenConvite});
      if (mounted) { if (result.data['sucesso'] == true) { setState(() { _conviteValido = true; _dadosConvite = Map<String, dynamic>.from(result.data['dadosConvite'])..['idConvite'] = result.data['idConvite']; _carregando = false; }); } else setState(() => _carregando = false); }
    } catch (_) { if (mounted) setState(() => _carregando = false); }
  }

  Future<void> _capturarFotoVip() async {
    final source = await showDialog<ImageSource>(context: context, builder: (ctx) => AlertDialog(title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Origem da Foto")), content: const Text("Como deseja enviar a foto do documento?"), actions:[TextButton.icon(icon: const Icon(Icons.folder), label: const Text("Arquivo / Galeria"), onPressed: () => Navigator.pop(ctx, ImageSource.gallery)), TextButton.icon(icon: const Icon(Icons.camera_alt), label: const Text("Tirar Foto (Webcam)"), onPressed: () => Navigator.pop(ctx, ImageSource.camera))]));
    if (source == null) return;
    try { final photo = await _picker.pickImage(source: source, maxWidth: 800); if (photo != null) { final bytes = await photo.readAsBytes(); setState(() { _fotoAnexada = true; _fotoBytes = bytes; }); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Foto capturada com sucesso!"))); } } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao acessar câmera ou arquivo."))); }
  }

  Future<void> _buscarHistorico() async {
    final doc = _docCtrl.text.trim().toUpperCase(); if (doc.isEmpty) return;
    setState(() => _buscandoHistorico = true);
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('validarLinkVip').call({'documento': doc});
      if (mounted && result.data['sucesso'] == true) { final dados = Map<String, dynamic>.from(result.data['historico']); setState(() { _nomeCtrl.text = dados['nome'] ?? ''; _vaiDeVeiculo = dados['usa_veiculo'] ?? false; if (_vaiDeVeiculo) { _modeloCorCtrl.text = dados['modelo_cor'] ?? ''; _placaCtrl.text = dados['placa'] ?? ''; _vagaCtrl.text = dados['vaga'] ?? ''; } }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bem-vindo de volta! Dados preenchidos automaticamente."))); }
    } catch (_) {}
    if (mounted) setState(() => _buscandoHistorico = false);
  }

  Future<void> _gerarCodigoAcesso() async {
    final colorScheme = Theme.of(context).colorScheme;
    if (_docCtrl.text.isEmpty || _nomeCtrl.text.isEmpty || !_fotoAnexada) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Preencha todos os campos e anexe a foto do documento!"), backgroundColor: colorScheme.error)); return; }
    if (_vaiDeVeiculo && (_modeloCorCtrl.text.isEmpty || _placaCtrl.text.isEmpty || _vagaCtrl.text.isEmpty)) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Preencha os dados do veículo e informe a Vaga!"), backgroundColor: colorScheme.error)); return; }
    setState(() => _carregando = true);
    try {
      final docFormatado = _docCtrl.text.trim().toUpperCase(); String caminhoInternoStorage = "";
      if (_fotoBytes != null) {
        final response = await http.post(Uri.parse('https://salvarfotovisitante-hhygy7dtpa-uc.a.run.app'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'data': {'image': base64Encode(_fotoBytes!), 'sindico': _dadosConvite!['sindico_vinculado'], 'documento': docFormatado, 'tokenConvite': widget.tokenConvite}}));
        if (response.statusCode == 200) { final r = jsonDecode(response.body)['result'] ?? jsonDecode(response.body)['data']; if (r != null && r['sucesso'] == true) caminhoInternoStorage = r['url']; else throw Exception(r?['erro'] ?? "Falha ao salvar a imagem no servidor"); } else { String err = response.body; try { final j = jsonDecode(response.body); if (j['error'] != null) err = j['error']['message'] ?? err; } catch(_) {} throw Exception("O servidor rejeitou a foto (${response.statusCode}): $err"); }
      }
      final result = await FirebaseFunctions.instance.httpsCallable('gerarAcessoVip').call({'idConvite': _dadosConvite!['idConvite'], 'documento': docFormatado, 'historicoVip': {'nome': _nomeCtrl.text.trim().toUpperCase(), 'usa_veiculo': _vaiDeVeiculo, 'modelo_cor': _vaiDeVeiculo ? _modeloCorCtrl.text.trim().toUpperCase() : '', 'placa': _vaiDeVeiculo ? _placaCtrl.text.trim().toUpperCase() : '', 'vaga': _vaiDeVeiculo ? _vagaCtrl.text.trim().toUpperCase() : ''}, 'dadosVip': {'sindico_vinculado': _dadosConvite!['sindico_vinculado'], 'bloco': _dadosConvite!['bloco'], 'ap': _dadosConvite!['ap'], 'morador_autorizou': _dadosConvite!['morador'], 'nome_visitante': _nomeCtrl.text.trim().toUpperCase(), 'documento': docFormatado, 'foto_doc_url': caminhoInternoStorage, 'usa_veiculo': _vaiDeVeiculo, 'modelo_cor': _vaiDeVeiculo ? _modeloCorCtrl.text.trim().toUpperCase() : '', 'placa': _vaiDeVeiculo ? _placaCtrl.text.trim().toUpperCase() : '', 'vaga': _vaiDeVeiculo ? _vagaCtrl.text.trim().toUpperCase() : ''}});
      if (!mounted) return;
      if (result.data['sucesso'] == true) setState(() { _codigoGerado = result.data['codigoGerado']; _carregando = false; }); else throw Exception("Erro ao gerar o código na nuvem.");
    } catch (e) { if (mounted) { setState(() => _carregando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: colorScheme.error)); } }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando && _codigoGerado.isEmpty) return Scaffold(appBar: AppBar(automaticallyImplyLeading: false, title: const Text("Carregando...", style: TextStyle(fontWeight: FontWeight.bold)), actions: const[BotaoTrocarTema()]), body: const Center(child: CircularProgressIndicator()));
    if (!_conviteValido && _codigoGerado.isEmpty) return Scaffold(appBar: AppBar(automaticallyImplyLeading: false, title: const Text("Acesso VIP", style: TextStyle(fontWeight: FontWeight.bold)), actions: const[BotaoTrocarTema()]), body: const Center(child: Text("Este link é inválido ou já foi utilizado.", style: TextStyle(fontSize: 18, color: Colors.red))));
    return PopScope(canPop: false, onPopInvokedWithResult: (d, r) { if (!d && !kIsWeb) SystemNavigator.pop(); }, child: Scaffold(appBar: AppBar(automaticallyImplyLeading: false, title: const Text("Cadastro de Visitante", style: TextStyle(fontWeight: FontWeight.bold)), actions: const [BotaoTrocarTema()]), body: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Container(width: 500, padding: const EdgeInsets.all(24), child: _codigoGerado.isNotEmpty ? _buildTelaCodigoGerado() : _buildFormulario())))));
  }

  Widget _buildTelaCodigoGerado() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children:[const Icon(Icons.check_circle, color: Colors.green, size: 80), const SizedBox(height: 20), const Text("Cadastro Concluído!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 10), const Text("Apresente o código abaixo na portaria para entrar:", textAlign: TextAlign.center, style: TextStyle(fontSize: 16)), const SizedBox(height: 30), Builder(builder: (ctx) { if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) ScreenProtector.protectDataLeakageOn(); return Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(15), border: Border.all(color: colorScheme.secondary, width: 2)), child: FittedBox(fit: BoxFit.scaleDown, child: Text(_codigoGerado, style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: 15, color: colorScheme.onSecondaryContainer)))); }), const SizedBox(height: 20), Text("Atenção: Este código é válido para apenas uma entrada.", style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold), textAlign: TextAlign.center)]);
  }

  Widget _buildFormulario() {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)), child: Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children:[Icon(Icons.info, color: colorScheme.onPrimaryContainer), Text("Você foi convidado por: ${_dadosConvite!['morador']} (Bloco ${_dadosConvite!['bloco']} / AP ${_dadosConvite!['ap']})", style: TextStyle(color: colorScheme.onPrimaryContainer))])), const SizedBox(height: 20), TextField(controller: _docCtrl, decoration: InputDecoration(labelText: "CPF ou RG", border: const OutlineInputBorder(), suffixIcon: _buscandoHistorico ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()) : const Icon(Icons.search)), inputFormatters:[DocumentoFormatter()], onEditingComplete: _buscarHistorico), const SizedBox(height: 15), TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: "Nome Completo", border: OutlineInputBorder()), inputFormatters:[UpperCaseTextFormatter()]), const SizedBox(height: 15), const Text("Como você vai entrar?", style: TextStyle(fontWeight: FontWeight.bold)), 
    // ignore: deprecated_member_use
    Row(children:[Expanded(child: RadioListTile<bool>(title: const Text("A pé"), value: false, groupValue: _vaiDeVeiculo, onChanged: (v) => setState(() => _vaiDeVeiculo = v!))), Expanded(child: RadioListTile<bool>(title: const Text("Veículo"), value: true, groupValue: _vaiDeVeiculo, onChanged: (v) => setState(() => _vaiDeVeiculo = v!)))]), if (_vaiDeVeiculo) ...[const SizedBox(height: 10), Row(children:[Expanded(flex: 2, child: TextField(controller: _modeloCorCtrl, decoration: const InputDecoration(labelText: "Modelo e Cor (Ex: COROLLA PRATA)", border: OutlineInputBorder()), inputFormatters:[UpperCaseTextFormatter()])), const SizedBox(width: 10), Expanded(flex: 1, child: TextField(controller: _placaCtrl, decoration: const InputDecoration(labelText: "Placa", border: OutlineInputBorder()), inputFormatters:[PlacaFormatter()]))]), const SizedBox(height: 10), TextField(controller: _vagaCtrl, decoration: const InputDecoration(labelText: "Vaga que irá utilizar (Ex: 102B)", border: OutlineInputBorder()), inputFormatters: [UpperCaseTextFormatter()])], const SizedBox(height: 20), const Text("Foto do Documento (Frente e Verso)", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 10), InkWell(onTap: _capturarFotoVip, child: Container(height: 100, decoration: BoxDecoration(color: _fotoAnexada ? Colors.green.withValues(alpha:0.1) : colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10), border: Border.all(color: _fotoAnexada ? Colors.green : colorScheme.outline)), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(_fotoAnexada ? Icons.check_circle : Icons.camera_alt, size: 40, color: _fotoAnexada ? Colors.green : colorScheme.onSurfaceVariant), const SizedBox(height: 5), Text(_fotoAnexada ? "Foto Anexada" : "Toque para carregar a foto do documento", style: TextStyle(color: _fotoAnexada ? Colors.green : colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))])))), const SizedBox(height: 30), LogicNeonButton(fullWidth: true, corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: _gerarCodigoAcesso, child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.qr_code, color: Colors.white, size: 18), SizedBox(width: 8), Text("GERAR CÓDIGO DE ENTRADA", style: TextStyle(color: Colors.white))]))]));
  }
}

// ============================================================================
// PARTE 8 - GESTÃO DO SÍNDICO (ADMINISTRAÇÃO LOCAL)
// ============================================================================

class TelaGestaoMoradores extends StatefulWidget {
  final String emailSindico;
  const TelaGestaoMoradores({super.key, required this.emailSindico});
  @override
  State<TelaGestaoMoradores> createState() => _TelaGestaoMoradoresState();
}

class _TelaGestaoMoradoresState extends State<TelaGestaoMoradores> with WidgetsBindingObserver {
  String busca = "", _buscaOperador = ""; String? blocoSelecionadoMorador, apSelecionadoMorador; DateTime? _dataFiltroInicio, _dataFiltroFim;
  late Stream<QuerySnapshot> _porteirosStream;
  List<Map<String, dynamic>> _moradoresCache = [], _auditoriaCache = [];
  bool _carregandoMoradores = true, _buscandoNuvem = false, _fimDaLista = false, _carregandoAuditoria = true, _buscandoNuvemAuditoria = false, _fimDaListaAuditoria = false;
  int _limiteVisivel = 30;
  final _scrollControllerMoradores = ScrollController(), _scrollControllerAuditoria = ScrollController();
  StreamSubscription<QuerySnapshot>? _novosMoradoresSub, _pendentesSub, _novasAuditoriasSub, _exclusoesSub;
  Timer? _debounceBuscaMoradores;

  void _modalEditarMenusPorteiro(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>, menus = Map<String, dynamic>.from(data['menus_personalizados'] ?? {}), opcoes = const {'encomendas': 'Recepção de Encomendas', 'visitantes': 'Controle de Visitantes', 'portoes': 'Abertura de Portões', 'cameras': 'Câmeras', 'ronda_virtual': 'Ronda Virtual', 'anotacoes': 'Anotações da Portaria'};
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) => AlertDialog(title: Text("Personalizar Menus: ${data['nome']}", style: const TextStyle(fontSize: 16)), content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Desmarque os itens que você deseja ESCONDER para este porteiro.", style: TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 10), ...opcoes.keys.map((key) => SwitchListTile(dense: true, title: Text(opcoes[key]!), value: menus[key] ?? true, activeThumbColor: Colors.blue, onChanged: (v) => setStateSB(() => menus[key] = v)))]))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), onPressed: () async { await doc.reference.update({'menus_personalizados': menus}); if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permissões salvas!"), backgroundColor: Colors.green)); } }, child: const Text("SALVAR"))])));
  }

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _scrollControllerMoradores.addListener(_aoRolarTelaMoradores); _scrollControllerAuditoria.addListener(_aoRolarTelaAuditoria); _initStreams(); _carregarMoradoresDeltaSync(); _carregarAuditoriaDeltaSync(); }

  void _aoRolarTelaMoradores() { if (_scrollControllerMoradores.position.pixels >= _scrollControllerMoradores.position.maxScrollExtent - 200 && !_buscandoNuvem && !_fimDaLista) { setState(() => _limiteVisivel += 30); if (_limiteVisivel > _moradoresCache.length) _buscarMaisAntigosNaNuvemMoradores(); } }
  void _aoRolarTelaAuditoria() { if (_scrollControllerAuditoria.position.pixels >= _scrollControllerAuditoria.position.maxScrollExtent - 200 && !_buscandoNuvemAuditoria && !_fimDaListaAuditoria && _buscaOperador.isEmpty && _dataFiltroInicio == null) _buscarMaisAntigosNaNuvemAuditoria(); }
  void _initStreams() { _porteirosStream = FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('perfil', isEqualTo: 'porteiro').snapshots(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _reconectarBancoDeDados(); }
  Future<void> _reconectarBancoDeDados() async { try { await FirebaseAuth.instance.currentUser?.getIdToken(true); setState(() { _initStreams(); _carregarMoradoresDeltaSync(); _carregarAuditoriaDeltaSync(); }); } catch (_) {} }

  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _scrollControllerMoradores.dispose(); _scrollControllerAuditoria.dispose(); _novosMoradoresSub?.cancel(); _pendentesSub?.cancel(); _novasAuditoriasSub?.cancel(); _exclusoesSub?.cancel(); _debounceBuscaMoradores?.cancel(); super.dispose(); }

  Future<void> _salvarCacheAuditoria(List<Map<String, dynamic>> lista) async { try { final jsonStr = jsonEncode(lista.map((item) => item.map((k, v) => MapEntry(k, v is Timestamp ? v.toDate().toIso8601String() : v))).toList()); if (kIsWeb) await (await SharedPreferences.getInstance()).setString('auditoria_delta_${widget.emailSindico}', jsonStr); else await File('${(await getApplicationDocumentsDirectory()).path}/auditoria_delta_${widget.emailSindico}.json').writeAsString(jsonStr); } catch (_) {} }

  Future<void> _carregarAuditoriaDeltaSync() async {
    try {
      String jsonString = ""; if (kIsWeb) jsonString = (await SharedPreferences.getInstance()).getString('auditoria_delta_${widget.emailSindico}') ?? ""; else { final file = File('${(await getApplicationDocumentsDirectory()).path}/auditoria_delta_${widget.emailSindico}.json'); if (await file.exists()) jsonString = await file.readAsString(); }
      if (jsonString.isNotEmpty) _auditoriaCache = (jsonDecode(jsonString) as List).map((item) { final mapa = Map<String, dynamic>.from(item); if (mapa['data_hora'] != null && mapa['data_hora'] is String) mapa['data_hora'] = Timestamp.fromDate(DateTime.parse(mapa['data_hora'])); return mapa; }).toList();
      if (mounted) setState(() => _carregandoAuditoria = false);

      Timestamp? ultimaData; if (_auditoriaCache.isNotEmpty) { _auditoriaCache.sort((a, b) => (b['data_hora'] as Timestamp).compareTo(a['data_hora'] as Timestamp)); ultimaData = _auditoriaCache.first['data_hora'] as Timestamp; }
      if (ultimaData == null) {
        if (mounted) setState(() => _buscandoNuvemAuditoria = true);
        for (var doc in (await FirebaseFirestore.instance.collection('auditoria').where('sindico_vinculado', isEqualTo: widget.emailSindico).orderBy('data_hora', descending: true).limit(30).get()).docs) _auditoriaCache.add(doc.data()..['id'] = doc.id);
        if (mounted) setState(() => _buscandoNuvemAuditoria = false); await _salvarCacheAuditoria(_auditoriaCache);
      } else {
        final snapNovos = await FirebaseFirestore.instance.collection('auditoria').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('data_hora', isGreaterThan: ultimaData).get();
        if (snapNovos.docs.isNotEmpty) { for (var doc in snapNovos.docs) _auditoriaCache.insert(0, doc.data()..['id'] = doc.id); _auditoriaCache.sort((a, b) => (b['data_hora'] as Timestamp).compareTo(a['data_hora'] as Timestamp)); if (mounted) setState(() {}); await _salvarCacheAuditoria(_auditoriaCache); }
      }

      _novasAuditoriasSub?.cancel();
      _novasAuditoriasSub = FirebaseFirestore.instance.collection('auditoria').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('data_hora', isGreaterThan: Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))).snapshots().listen((snap) {
        bool alterou = false;
        for (var change in snap.docChanges) { final data = change.doc.data()!..['id'] = change.doc.id; if (change.type == DocumentChangeType.added && !_auditoriaCache.any((a) => a['id'] == change.doc.id)) { _auditoriaCache.insert(0, data); alterou = true; } }
        if (alterou) { _auditoriaCache.sort((a, b) => (b['data_hora'] as Timestamp).compareTo(a['data_hora'] as Timestamp)); if (mounted) setState(() {}); _salvarCacheAuditoria(_auditoriaCache); }
      });
    } catch (_) { if (mounted) setState(() => _carregandoAuditoria = false); }
  }

  Future<void> _buscarMaisAntigosNaNuvemAuditoria() async {
    setState(() => _buscandoNuvemAuditoria = true);
    try {
      final dataMaisVelha = _auditoriaCache.isNotEmpty ? _auditoriaCache.last['data_hora'] as Timestamp? : null;
      if (dataMaisVelha != null) {
        final snap = await FirebaseFirestore.instance.collection('auditoria').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('data_hora', isLessThan: dataMaisVelha).orderBy('data_hora', descending: true).limit(20).get();
        if (snap.docs.isNotEmpty) { for (var doc in snap.docs) { final data = doc.data()..['id'] = doc.id; if (!_auditoriaCache.any((m) => m['id'] == doc.id)) _auditoriaCache.add(data); } if (mounted) setState(() {}); _salvarCacheAuditoria(_auditoriaCache); } else _fimDaListaAuditoria = true;
      }
    } catch (_) {}
    if (mounted) setState(() => _buscandoNuvemAuditoria = false);
  }

  Future<void> _salvarCacheMoradores(List<Map<String, dynamic>> lista) async { try { final jsonStr = jsonEncode(lista.map((item) => item.map((k, v) => MapEntry(k, v is Timestamp ? v.toDate().toIso8601String() : v))).toList()); if (kIsWeb) await (await SharedPreferences.getInstance()).setString('gestao_morador_${widget.emailSindico}', jsonStr); else await File('${(await getApplicationDocumentsDirectory()).path}/gestao_morador_${widget.emailSindico}.json').writeAsString(jsonStr); } catch (_) {} }

  Future<void> _carregarMoradoresDeltaSync() async {
    try {
      // 1. Carrega do cache local para a tela abrir piscar rápido
      String jsonString = ""; if (kIsWeb) jsonString = (await SharedPreferences.getInstance()).getString('gestao_morador_${widget.emailSindico}') ?? ""; else { final file = File('${(await getApplicationDocumentsDirectory()).path}/gestao_morador_${widget.emailSindico}.json'); if (await file.exists()) jsonString = await file.readAsString(); }
      if (jsonString.isNotEmpty) {
         _moradoresCache = (jsonDecode(jsonString) as List).map((item) { final mapa = Map<String, dynamic>.from(item); if (mapa['data_registro'] != null && mapa['data_registro'] is String) mapa['data_registro'] = Timestamp.fromDate(DateTime.parse(mapa['data_registro'])); return mapa; }).toList();
         if (mounted) setState(() => _carregandoMoradores = false);
      }

      // 2. MÁGICA: Escuta TUDO em tempo real com uma regra simples que NUNCA dá erro de índice!
      // Pendentes, aprovados e removidos atualizam no exato milissegundo.
      _novosMoradoresSub?.cancel();
      _novosMoradoresSub = FirebaseFirestore.instance.collection('usuarios')
        .where('sindico_vinculado', isEqualTo: widget.emailSindico)
        .where('perfil', isEqualTo: 'morador')
        .snapshots().listen((snap) {
          bool alterou = false;
          for (var change in snap.docChanges) { 
            final data = change.doc.data()!..['id'] = change.doc.id; 
            final idx = _moradoresCache.indexWhere((v) => v['id'] == change.doc.id); 
            if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) { 
              if (idx != -1) _moradoresCache[idx] = data; 
              else _moradoresCache.insert(0, data); 
              alterou = true; 
            } else if (change.type == DocumentChangeType.removed && idx != -1) { 
              _moradoresCache.removeAt(idx); 
              alterou = true; 
            } 
          }
          if (alterou || _carregandoMoradores) { 
            if (mounted) setState(() => _carregandoMoradores = false); 
            _salvarCacheMoradores(_moradoresCache); 
          }
      }, onError: (e) {
         debugPrint("Erro no stream instantâneo de moradores: $e");
         if (mounted) setState(() => _carregandoMoradores = false);
      });
    } catch (_) { if (mounted) setState(() => _carregandoMoradores = false); }
  }

  Future<void> _buscarMaisAntigosNaNuvemMoradores() async {
    // Obsoleto: O novo stream inteligente já traz todos os moradores em tempo real.
    // Apenas finalizamos a lista para a interface entender que acabou.
    setState(() => _fimDaLista = true);
  }

  void _aoDigitarBuscaMoradores(String valor) {
    setState(() => busca = valor.toLowerCase().trim()); if (busca.isEmpty) return;
    _debounceBuscaMoradores?.cancel();
    _debounceBuscaMoradores = Timer(const Duration(milliseconds: 800), () async {
      if (!_moradoresCache.any((m) => (m['nome'] ?? '').toString().toLowerCase().contains(busca) || (m['bloco'] ?? '').toString().toLowerCase().contains(busca) || (m['ap'] ?? '').toString().toLowerCase().contains(busca) || "${m['bloco']}-${m['ap']}".contains(busca.replaceAll(' ', '')))) {
        setState(() => _buscandoNuvem = true);
        try {
          final termoUpper = busca.toUpperCase(), snap = await FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('perfil', isEqualTo: 'morador').where('nome', isGreaterThanOrEqualTo: termoUpper).where('nome', isLessThan: '${termoUpper}z').limit(10).get();
          if (snap.docs.isNotEmpty) { bool salvou = false; for (var doc in snap.docs) { final data = doc.data()..['id'] = doc.id; if (!_moradoresCache.any((m) => m['id'] == doc.id)) { _moradoresCache.insert(0, data); salvou = true; } } if (salvou) { if (mounted) setState(() {}); _salvarCacheMoradores(_moradoresCache); } }
        } catch (_) {}
        if (mounted) setState(() => _buscandoNuvem = false);
      }
    });
  }

  Widget _linhaInfoAuditoria(String rotulo, String valor, ColorScheme colorScheme) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[SizedBox(width: 140, child: Text(rotulo, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold))), Expanded(child: Text(valor, style: TextStyle(color: colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold)))]));

  void _cadastrarPorteiro() {
    String nome = "", email = "", senha = ""; bool criando = false, ocultarSenhaPorteiro = true;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Cadastrar Novo Porteiro")),
        content: Column(mainAxisSize: MainAxisSize.min, children:[TextField(onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: "Nome do Porteiro")), TextField(onChanged: (v) => email = v.toLowerCase().trim(), decoration: const InputDecoration(labelText: "E-mail de Acesso")), TextField(onChanged: (v) => senha = v, obscureText: ocultarSenhaPorteiro, decoration: InputDecoration(labelText: "Senha", suffixIcon: IconButton(icon: Icon(ocultarSenhaPorteiro ? Icons.visibility_off : Icons.visibility), onPressed: () => setStateSB(() => ocultarSenhaPorteiro = !ocultarSenhaPorteiro))))]),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          criando ? const CircularProgressIndicator() : ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async {
            if (email.isNotEmpty && senha.isNotEmpty) {
              setStateSB(() => criando = true);
              try {
                final resultado = await FirebaseService.criarUsuarioSaaS(email: email, senha: senha, nome: nome, perfil: 'porteiro', sindicoVinculado: widget.emailSindico, servicoAtivo: true);
                if (mounted) { if (resultado['sucesso'] == true) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Porteiro criado com sucesso!"), backgroundColor: Colors.green)); } else { setStateSB(() => criando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(resultado['erro'])), backgroundColor: colorScheme.error)); } }
              } catch (e) { setStateSB(() => criando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: colorScheme.error)); }
            }
          }, child: const Text("SALVAR"))
        ],
      );
    }));
  }

  void _resetarSenhaMorador(String email, String nome) {
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Resetar Senha")), content: Text("O sistema enviará um link oficial de recuperação para o e-mail de $nome ($email). Confirma?"), actions:[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: colorScheme.onSecondary), onPressed: () async { try { await FirebaseAuth.instance.sendPasswordResetEmail(email: email); if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link de redefinição enviado com sucesso!"), backgroundColor: Colors.green)); } } catch (e) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: colorScheme.error)); } }, child: const Text("ENVIAR LINK"))]);
    });
  }

  void _mostrarDadosMorador(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>, colorScheme = Theme.of(context).colorScheme;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children:[Icon(Icons.person, color: colorScheme.primary), FittedBox(fit: BoxFit.scaleDown, child: Text(data['nome'] ?? 'Sem nome'))]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[
        FittedBox(fit: BoxFit.scaleDown, child: Text("📍 Bloco: ${data['bloco']} | AP: ${data['ap']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))), const Divider(), FittedBox(fit: BoxFit.scaleDown, child: Text("Nascimento: ${data['data_nascimento'] ?? 'N/D'} | Tel: ${data['telefone'] ?? 'N/D'}", style: const TextStyle(fontSize: 14))), FittedBox(fit: BoxFit.scaleDown, child: Text("E-mail: ${data['email'] ?? 'N/D'}", style: const TextStyle(fontSize: 14))), const SizedBox(height: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha:0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: colorScheme.primary)), child: Text("Declarou ser: ${(data['tipo_ocupacao'] ?? 'INQUILINO').toString().toUpperCase()}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.primary))), if (data['tipo_ocupacao'] == 'proprietario' && data['cpf'] != null && data['cpf'].toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 5), child: FittedBox(fit: BoxFit.scaleDown, child: Text("CPF Financeiro: ${data['cpf']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)))), const SizedBox(height: 15), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: data['status'] == 'pendente' ? Colors.orange.withValues(alpha:0.2) : Colors.green.withValues(alpha:0.2), borderRadius: BorderRadius.circular(5)), child: Text("Status: ${data['status'].toString().toUpperCase()}", style: TextStyle(color: data['status'] == 'pendente' ? Colors.orange : Colors.green, fontWeight: FontWeight.bold))), if (data['status'] == 'aprovado' && data.containsKey('aprovado_por')) ...[const SizedBox(height: 15), FittedBox(fit: BoxFit.scaleDown, child: Text("✅ Aprovado por: ${data['aprovado_por']}", style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.green)))], const SizedBox(height: 20), SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondaryContainer, foregroundColor: colorScheme.onSecondaryContainer), icon: const Icon(Icons.lock_reset), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("ENVIAR RESET DE SENHA")), onPressed: () { Navigator.pop(ctx); _resetarSenhaMorador(data['email'], data['nome']); }))
      ]),
      actions:[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FECHAR"))],
    ));
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(length: 4, child: Scaffold(
    appBar: AppBar(title: const Text("Central de Gestão"), bottom: TabBar(isScrollable: true, tabs:[const Tab(text: "Porteiros"), Tab(key: keyTutGesAbaMoradores, text: "Moradores"), Tab(key: keyTutGesAbaPermissoes, text: "Permissões App"), const Tab(text: "Auditoria/Histórico")])),
    body: TabBarView(children:[_abaPorteiros(), _abaMoradores(), _abaPermissoes(), _abaAuditoria()]),
  ));

  Widget _abaPorteiros() {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(key: keyTutGesNovoPorteiro, onPressed: _cadastrarPorteiro, icon: const Icon(Icons.add), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("Cadastrar Porteiro"))),
      body: Column(children:[
        const Padding(padding: EdgeInsets.all(16.0), child: Align(alignment: Alignment.centerLeft, child: Text("Equipe de Portaria", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: _porteirosStream, builder: (context, snap) {
          if (snap.hasError) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.wifi_off, size: 50, color: colorScheme.error), const SizedBox(height: 15), Text("Sessão expirada ou erro de conexão.", style: TextStyle(color: colorScheme.onSurfaceVariant)), const SizedBox(height: 10), ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("Recarregar"), onPressed: _reconectarBancoDeDados)]));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhum porteiro cadastrado."));
          return ListView(padding: const EdgeInsets.all(16), children: snap.data!.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return Card(child: ListTile(leading: CircleAvatar(backgroundColor: colorScheme.primary, child: Icon(Icons.security, color: colorScheme.onPrimary)), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'] ?? "")), subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Acesso: ${data['email'] ?? ""}")), trailing: FittedBox(fit: BoxFit.scaleDown, child: Row(mainAxisSize: MainAxisSize.min, children:[IconButton(icon: Icon(Icons.view_sidebar, color: colorScheme.primary), tooltip: "Ocultar Menus", onPressed: () => _modalEditarMenusPorteiro(d)), IconButton(icon: Icon(Icons.lock_reset, color: colorScheme.secondary), tooltip: "Resetar Senha", onPressed: () => _resetarSenhaMorador(data['email'], data['nome'])), IconButton(icon: Icon(Icons.delete, color: colorScheme.error), tooltip: "Excluir", onPressed: () => d.reference.delete())]))));
          }).toList());
        }))
      ])
    );
  }

  Widget _abaMoradores() {
    final colorScheme = Theme.of(context).colorScheme;
    String pad(String v) { String s = v.trim().toUpperCase(); return int.tryParse(s) != null ? int.parse(s).toString().padLeft(2, '0') : s; }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
      Padding(padding: const EdgeInsets.all(16), child: TextField(onChanged: _aoDigitarBuscaMoradores, decoration: InputDecoration(labelText: "Pesquisar (Nome ou Bloco-AP. Ex: 10-12)", prefixIcon: const Icon(Icons.search), suffixIcon: _buscandoNuvem ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null, border: const OutlineInputBorder()))),
      if (busca.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children:[TextButton.icon(icon: const Icon(Icons.business), label: const Text("Todos os Blocos"), onPressed: () => setState(() { blocoSelecionadoMorador = null; apSelecionadoMorador = null; })), if (blocoSelecionadoMorador != null) ...[const Icon(Icons.chevron_right, color: Colors.grey), TextButton.icon(icon: const Icon(Icons.meeting_room), label: Text("Bloco $blocoSelecionadoMorador"), onPressed: () => setState(() => apSelecionadoMorador = null))], if (apSelecionadoMorador != null) ...[const Icon(Icons.chevron_right, color: Colors.grey), TextButton.icon(icon: const Icon(Icons.person), label: Text("AP $apSelecionadoMorador"), onPressed: () {})]]))),
      Expanded(child: _carregandoMoradores ? const Center(child: CircularProgressIndicator()) : Builder(builder: (context) {
        if (busca.isEmpty && blocoSelecionadoMorador == null) {
          final blocosSet = _moradoresCache.map((d) => pad((d['bloco'] ?? '').toString())).toSet().toList()..removeWhere((b) => b.isEmpty)..sort();
          if (blocosSet.isEmpty) return const Center(child: Text("Nenhum morador no condomínio."));
          return GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, childAspectRatio: 1.2, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: blocosSet.length, itemBuilder: (context, index) {
            final bloco = blocosSet[index], qtdMoradores = _moradoresCache.where((d) => pad((d['bloco'] ?? '').toString()) == bloco).length, pendentes = _moradoresCache.where((d) => pad((d['bloco'] ?? '').toString()) == bloco && d['status'] == 'pendente').length, temPendente = pendentes > 0;
            return InkWell(onTap: () => setState(() => blocoSelecionadoMorador = bloco), child: Card(color: temPendente ? Colors.orange.shade800 : colorScheme.primaryContainer, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: temPendente ? Colors.orangeAccent : colorScheme.primary.withValues(alpha:0.3), width: temPendente ? 2 : 1)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.business, size: 50, color: temPendente ? Colors.white : colorScheme.primary), const SizedBox(height: 10), FittedBox(fit: BoxFit.scaleDown, child: Text("Bloco $bloco", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: temPendente ? Colors.white : colorScheme.onPrimaryContainer))), FittedBox(fit: BoxFit.scaleDown, child: Text("$qtdMoradores Morador(es)", style: TextStyle(color: temPendente ? Colors.white70 : colorScheme.onPrimaryContainer.withValues(alpha:0.7)))), if (temPendente) Container(margin: const EdgeInsets.only(top: 5), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)), child: Text("$pendentes PENDENTE(S)", style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.bold)))])));
          });
        }
        if (busca.isEmpty && apSelecionadoMorador == null) {
          final apsCache = _moradoresCache.where((d) => pad((d['bloco'] ?? '').toString()) == blocoSelecionadoMorador).toList(), apsSet = apsCache.map((d) => pad((d['ap'] ?? '').toString())).toSet().toList()..removeWhere((a) => a.isEmpty)..sort();
          return GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 150, childAspectRatio: 1.0, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: apsSet.length, itemBuilder: (context, index) {
            final ap = apsSet[index], qtdMoradores = apsCache.where((d) => pad((d['ap'] ?? '').toString()) == ap).length, pendentes = apsCache.where((d) => pad((d['ap'] ?? '').toString()) == ap && d['status'] == 'pendente').length, temPendente = pendentes > 0;
            return InkWell(onTap: () => setState(() => apSelecionadoMorador = ap), child: Card(color: temPendente ? Colors.orange.shade800 : colorScheme.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: temPendente ? Colors.orangeAccent : colorScheme.outlineVariant, width: temPendente ? 2 : 1)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.meeting_room, size: 40, color: temPendente ? Colors.white : colorScheme.onSurfaceVariant), const SizedBox(height: 10), FittedBox(fit: BoxFit.scaleDown, child: Text("AP $ap", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: temPendente ? Colors.white : colorScheme.onSurface))), FittedBox(fit: BoxFit.scaleDown, child: Text("$qtdMoradores Morador(es)", style: TextStyle(color: temPendente ? Colors.white70 : colorScheme.onSurfaceVariant, fontSize: 12))), if (temPendente) Container(margin: const EdgeInsets.only(top: 5), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)), child: Text("$pendentes PENDENTE(S)", style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.bold)))])));
          });
        }
        final listaM = _moradoresCache.where((m) {
          if (m['status'] == 'excluido') return false;
          if (busca.isNotEmpty) return (m['nome'] ?? '').toString().toLowerCase().contains(busca) || (m['bloco'] ?? '').toString().toLowerCase().contains(busca) || (m['ap'] ?? '').toString().toLowerCase().contains(busca) || "${m['bloco']}-${m['ap']}".contains(busca.replaceAll(' ', ''));
          return pad((m['bloco'] ?? '').toString()) == blocoSelecionadoMorador && pad((m['ap'] ?? '').toString()) == apSelecionadoMorador;
        }).toList()..sort((a, b) { final statusCmp = (a['status'] == 'pendente' ? 0 : 1).compareTo(b['status'] == 'pendente' ? 0 : 1); if (statusCmp != 0) return statusCmp; return (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()); });
        final listaPaginada = listaM.take(_limiteVisivel).toList();
        if (listaPaginada.isEmpty) return _buscandoNuvem ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 15), Text("Sincronizando com a Nuvem...")])) : const Center(child: Text("Nenhum morador encontrado no condomínio."));

        return ListView.builder(controller: _scrollControllerMoradores, padding: const EdgeInsets.all(16), itemCount: listaPaginada.length + (_buscandoNuvem ? 1 : 0), itemBuilder: (context, index) {
          if (index == listaPaginada.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Buscando mais antigos na nuvem...", style: TextStyle(color: Colors.grey))])));
          final data = listaPaginada[index], isPendente = data['status'] == 'pendente';
          final blocoExibir = pad((data['bloco'] ?? '').toString());
          final apExibir = pad((data['ap'] ?? '').toString());
          return Card(color: isPendente ? colorScheme.tertiaryContainer : colorScheme.surface, elevation: 2, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isPendente ? colorScheme.tertiary : colorScheme.outlineVariant)), child: ListTile(onTap: () async { final docR = await FirebaseFirestore.instance.collection('usuarios').doc(data['id']).get(); if (docR.exists) _mostrarDadosMorador(docR); }, leading: CircleAvatar(backgroundColor: isPendente ? colorScheme.tertiary : Colors.green, child: Icon(Icons.person, color: isPendente ? colorScheme.onTertiary : Colors.white)), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'] ?? 'Sem Nome', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isPendente ? colorScheme.onTertiaryContainer : colorScheme.onSurface))), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("B: $blocoExibir | AP: $apExibir", style: TextStyle(color: isPendente ? colorScheme.onTertiaryContainer : colorScheme.onSurfaceVariant)), if (!isPendente) Text("Aprovado por: ${data['aprovado_por'] ?? 'S/R'}", style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold))]), trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (isPendente) IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), tooltip: "Aprovar Morador", onPressed: () async { await FirebaseFirestore.instance.collection('usuarios').doc(data['id']).update({'status': 'aprovado', 'servico_ativo': true, 'aprovado_por': operadorLogado, 'data_aprovacao': FieldValue.serverTimestamp()}); final idx = _moradoresCache.indexWhere((v) => v['id'] == data['id']); if (idx != -1) setState(() => _moradoresCache[idx]['status'] = 'aprovado'); }) else IconButton(icon: Icon(Icons.info, color: colorScheme.primary), tooltip: "Ver Detalhes", onPressed: () async { final docR = await FirebaseFirestore.instance.collection('usuarios').doc(data['id']).get(); if (docR.exists) _mostrarDadosMorador(docR); }), IconButton(icon: Icon(Icons.delete, color: colorScheme.error), tooltip: "Remover Morador", onPressed: () async { final batch = FirebaseFirestore.instance.batch(); batch.set(FirebaseFirestore.instance.collection('pedidos_exclusao').doc(), {'sindico_vinculado': widget.emailSindico, 'colecao': 'usuarios', 'doc_id': data['id'], 'data_exclusao': FieldValue.serverTimestamp()}); batch.delete(FirebaseFirestore.instance.collection('usuarios').doc(data['id'])); await batch.commit(); setState(() => _moradoresCache.removeWhere((v) => v['id'] == data['id'])); _salvarCacheMoradores(_moradoresCache); })])));
        });
      }))
    ]);
  }

  Widget _abaPermissoes() {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 800;
      final cardPortoes = Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[const FittedBox(fit: BoxFit.scaleDown, child: Text("Permissões de Portões", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, child: Text("Define quais portões os moradores podem abrir no app.", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12))), const Divider(), StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('portoes').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots(), builder: (context, snap) { if (snap.hasError || !snap.hasData) return const Center(child: CircularProgressIndicator()); if (snap.data!.docs.isEmpty) return const Text("Nenhum portão instalado pelo técnico ainda."); return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) { final doc = snap.data!.docs[i], data = doc.data() as Map<String, dynamic>; return SwitchListTile(title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'], style: const TextStyle(fontWeight: FontWeight.bold))), subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Control iD: ${data['id_box']}")), value: data['permite_morador'] ?? false, activeThumbColor: colorScheme.primary, onChanged: (v) => doc.reference.update({'permite_morador': v})); }); })])));
      final cardCameras = Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[const FittedBox(fit: BoxFit.scaleDown, child: Text("Permissões de Câmeras", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, child: Text("Define quais câmeras os moradores podem visualizar ao vivo.", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12))), const Divider(), StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('cameras').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots(), builder: (context, snap) { if (snap.hasError || !snap.hasData) return const Center(child: CircularProgressIndicator()); if (snap.data!.docs.isEmpty) return const Text("Nenhuma câmera instalada pelo técnico ainda."); return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) { final doc = snap.data!.docs[i], data = doc.data() as Map<String, dynamic>; return SwitchListTile(title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'], style: const TextStyle(fontWeight: FontWeight.bold))), subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("IP: ${data['ip']}")), value: data['visivel_morador'] ?? false, activeThumbColor: colorScheme.primary, onChanged: (v) => doc.reference.update({'visivel_morador': v})); }); })])));
      final cardFinanceiro = Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[const FittedBox(fit: BoxFit.scaleDown, child: Text("Regras Financeiras", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, child: Text("Restrições aplicadas a moradores inadimplentes.", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12))), const Divider(), StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('usuarios').doc(widget.emailSindico).snapshots(), builder: (context, snap) { if (snap.hasError || !snap.hasData || !snap.data!.exists) return const Center(child: CircularProgressIndicator()); final data = snap.data!.data() as Map<String, dynamic>; return SwitchListTile(title: const Text("Bloquear Reservas de Áreas Comuns", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)), subtitle: const Text("Moradores com faturas vencidas não poderão alugar o salão de festas, quiosques, etc.", style: TextStyle(fontSize: 12)), value: data['bloquear_inadimplentes'] ?? false, activeThumbColor: Colors.orange, onChanged: (v) => snap.data!.reference.update({'bloquear_inadimplentes': v})); })])));
      final cardLogistica = Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[const FittedBox(fit: BoxFit.scaleDown, child: Text("Logística e Encomendas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, child: Text("Configurações da recepção de pacotes na portaria.", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12))), const Divider(), StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('usuarios').doc(widget.emailSindico).snapshots(), builder: (context, snap) { if (snap.hasError || !snap.hasData || !snap.data!.exists) return const Center(child: CircularProgressIndicator()); final data = snap.data!.data() as Map<String, dynamic>; return SwitchListTile(title: const Text("Usar Impressora de Etiquetas (Térmica)", style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text("Ao invés de escrever com canetão, o sistema imprime uma etiqueta com o Bloco e AP gigantes para colar na caixa.", style: TextStyle(fontSize: 12)), value: data['usar_impressora_etiquetas'] ?? false, activeThumbColor: colorScheme.primary, onChanged: (v) => snap.data!.reference.update({'usar_impressora_etiquetas': v})); })])));
      final cardIdade = Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[const FittedBox(fit: BoxFit.scaleDown, child: Text("Classificação Etária (Menores)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, child: Text("Idade mínima para usar funções críticas do App.", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12))), const Divider(), StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('usuarios').doc(widget.emailSindico).snapshots(), builder: (context, snap) { if (snap.hasError || !snap.hasData || !snap.data!.exists) return const Center(child: CircularProgressIndicator()); final data = snap.data!.data() as Map<String, dynamic>; return Column(children: [ListTile(title: const Text("Abertura de Portões e Câmeras", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: const Text("Menores que isso não verão as câmeras nem os botões de portão."), trailing: DropdownButton<int>(value: data['idade_minima_portoes'] ?? 18, items: [12, 14, 16, 18].map((i) => DropdownMenuItem(value: i, child: Text("$i anos"))).toList(), onChanged: (v) => snap.data!.reference.update({'idade_minima_portoes': v}))), ListTile(title: const Text("Retirada de Encomendas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: const Text("Idade para gerar PIN e retirar pacotes."), trailing: DropdownButton<int>(value: data['idade_minima_encomendas'] ?? 12, items: [10, 12, 14, 16, 18].map((i) => DropdownMenuItem(value: i, child: Text("$i anos"))).toList(), onChanged: (v) => snap.data!.reference.update({'idade_minima_encomendas': v})))]); })])));
      return SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16.0), child: isMobile ? Column(children: [cardPortoes, const SizedBox(height: 16), cardCameras, const SizedBox(height: 16), cardFinanceiro, const SizedBox(height: 16), cardLogistica, const SizedBox(height: 16), cardIdade]) : Column(children: [Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cardPortoes), const SizedBox(width: 16), Expanded(child: cardCameras)]), const SizedBox(height: 16), Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cardFinanceiro), const SizedBox(width: 16), Expanded(child: cardLogistica)]), const SizedBox(height: 16), Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: cardIdade), const SizedBox(width: 16), const Spacer()])])));
    });
  }

  Future<void> _selecionarDataFiltroAuditoria(BuildContext context) async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now(), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme), child: child!));
    if (picked != null) setState(() { _dataFiltroInicio = picked.start; _dataFiltroFim = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59); });
  }

  Widget _abaAuditoria() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(children:[
      Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children:[SizedBox(width: 300, child: TextField(onChanged: (v) => setState(() => _buscaOperador = v.toLowerCase()), decoration: const InputDecoration(labelText: "Filtrar por Operador/Usuário", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))), FittedBox(fit: BoxFit.scaleDown, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: _dataFiltroInicio != null ? colorScheme.primary : colorScheme.surfaceContainerHighest, foregroundColor: _dataFiltroInicio != null ? colorScheme.onPrimary : colorScheme.onSurfaceVariant, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15)), icon: const Icon(Icons.calendar_month), label: Text(_dataFiltroInicio != null ? "${DateFormat('dd/MM').format(_dataFiltroInicio!)} - ${DateFormat('dd/MM').format(_dataFiltroFim!)}" : "Filtrar Data"), onPressed: () => _selecionarDataFiltroAuditoria(context))), if (_dataFiltroInicio != null) IconButton(icon: Icon(Icons.clear, color: colorScheme.error), onPressed: () => setState(() { _dataFiltroInicio = null; _dataFiltroFim = null; }))])),
      Expanded(child: _carregandoAuditoria ? const Center(child: CircularProgressIndicator()) : Builder(builder: (context) {
        final filtrados = _auditoriaCache.where((data) {
          if (_dataFiltroInicio != null && data['data_hora'] != null) { final dt = (data['data_hora'] as Timestamp).toDate(); if (dt.isBefore(_dataFiltroInicio!) || dt.isAfter(_dataFiltroFim!)) return false; }
          if (_buscaOperador.isNotEmpty && !(data['operador'] ?? "").toString().toLowerCase().contains(_buscaOperador)) return false;
          return true;
        }).toList();
        if (filtrados.isEmpty) return const Center(child: Text("Nenhum registro de auditoria encontrado."));

        return ListView.builder(controller: _scrollControllerAuditoria, padding: const EdgeInsets.all(16), itemCount: filtrados.length + (_buscandoNuvemAuditoria ? 1 : 0), itemBuilder: (ctx, i) {
          if (i == filtrados.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Buscando histórico na nuvem...", style: TextStyle(color: Colors.grey))])));
          final data = filtrados[i], dataStr = data['data_hora'] != null ? DateFormat('dd/MM/yyyy HH:mm').format((data['data_hora'] as Timestamp).toDate()) : "Não Registrado";
          IconData iconModulo = Icons.info; Color corModulo = Colors.grey;
          if (data['modulo'] == 'Controle de Acessos') { iconModulo = Icons.door_sliding; corModulo = Colors.green; } else if (data['modulo'] == 'Encomendas') { iconModulo = Icons.inventory_2; corModulo = Colors.orange; } else if (data['modulo'] == 'Visitantes') { iconModulo = Icons.people; corModulo = Colors.blue; } else if (data['modulo'] == 'Interfonia/App') { iconModulo = Icons.mobile_friendly; corModulo = Colors.purple; } else if (data['modulo'] == 'Estoque') { iconModulo = Icons.grid_view; corModulo = Colors.teal; }
          return Card(color: colorScheme.surface, elevation: 3, margin: const EdgeInsets.only(bottom: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Row(children:[CircleAvatar(backgroundColor: corModulo.withValues(alpha:0.2), child: Icon(iconModulo, color: corModulo)), const SizedBox(width: 10), Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("${data['acao']} - ${data['modulo']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))), FittedBox(fit: BoxFit.scaleDown, child: Text(dataStr, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)))]), const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()), _linhaInfoAuditoria("Operador/Responsável:", data['operador'] ?? 'N/D', colorScheme), const SizedBox(height: 5), Text("Detalhes da Operação:", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(5)), child: Text(data['detalhes'] ?? "Sem detalhes adicionais.", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)))])));
        });
      }))
    ]);
  }
}

class TelaCadastroSindico extends StatefulWidget {
  const TelaCadastroSindico({super.key});
  @override
  State<TelaCadastroSindico> createState() => _TelaCadastroSindicoState();
}

class _TelaCadastroSindicoState extends State<TelaCadastroSindico> {
  int _etapa = 0; bool _carregando = false, _ocultarSenha = true, _aceitouTermos = false;
  final _condominioCtrl = TextEditingController(), _nomeCtrl = TextEditingController(), _telefoneCtrl = TextEditingController(), _emailCtrl = TextEditingController(), _senhaCtrl = TextEditingController(), _codigoDigitadoCtrl = TextEditingController(), _cpfCnpjCtrl = TextEditingController();
  String _idCondominioGerado = "", _codigoVerificacaoCorreto = "";

  @override
  void initState() {
    super.initState();
    _carregarRascunho();
  }

  Future<void> _carregarRascunho() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('rascunho_sindico');
      if (str != null) {
        final data = jsonDecode(str);
        if (DateTime.now().millisecondsSinceEpoch - (data['timestamp'] ?? 0) < 3600000) {
          setState(() {
            _condominioCtrl.text = data['condominio'] ?? '';
            _nomeCtrl.text = data['nome'] ?? '';
            _cpfCnpjCtrl.text = data['cpf'] ?? '';
            _telefoneCtrl.text = data['telefone'] ?? '';
            _emailCtrl.text = data['email'] ?? '';
            _senhaCtrl.text = data['senha'] ?? '';
            _codigoVerificacaoCorreto = data['codigo'] ?? '';
            _aceitouTermos = true;
            _etapa = 1;
          });
        } else {
          prefs.remove('rascunho_sindico');
        }
      }
    } catch (_) {}
  }

  Future<void> _salvarRascunho() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rascunho_sindico', jsonEncode({
        'condominio': _condominioCtrl.text, 'nome': _nomeCtrl.text, 'cpf': _cpfCnpjCtrl.text,
        'telefone': _telefoneCtrl.text, 'email': _emailCtrl.text, 'senha': _senhaCtrl.text,
        'codigo': _codigoVerificacaoCorreto, 'timestamp': DateTime.now().millisecondsSinceEpoch
      }));
    } catch (_) {}
  }

  Future<void> _limparRascunho() async {
    try { (await SharedPreferences.getInstance()).remove('rascunho_sindico'); } catch (_) {}
  }

  @override
  void dispose() { _condominioCtrl.dispose(); _nomeCtrl.dispose(); _telefoneCtrl.dispose(); _emailCtrl.dispose(); _senhaCtrl.dispose(); _codigoDigitadoCtrl.dispose(); _cpfCnpjCtrl.dispose(); super.dispose(); }

  Future<void> _enviarCodigo() async {
    if (_condominioCtrl.text.trim().isEmpty || _nomeCtrl.text.trim().isEmpty || _cpfCnpjCtrl.text.trim().isEmpty || _telefoneCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty || _senhaCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos obrigatórios."))); return; }
    if (_senhaCtrl.text.length < 6) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("A senha deve ter pelo menos 6 caracteres."))); return; }
    if (!_aceitouTermos) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Você precisa aceitar os Termos de Uso."))); return; }
    setState(() => _carregando = true);
    final resposta = await HelperEmail.enviarCodigo(emailDestino: _emailCtrl.text.trim().toLowerCase(), nome: _nomeCtrl.text.trim(), perfil: 'sindico');
    if (resposta['status'] == 'sucesso') {
      setState(() { _codigoVerificacaoCorreto = resposta['codigo_gerado']; _etapa = 1; _carregando = false; });
      await _salvarRascunho();
    } else { setState(() => _carregando = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(resposta['erro'] ?? "Erro ao enviar e-mail.")), backgroundColor: Colors.red)); }
  }

  Future<void> _validarECriarConta() async {
    if (_codigoDigitadoCtrl.text.trim() != _codigoVerificacaoCorreto) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Código incorreto. Verifique o e-mail."), backgroundColor: Colors.red)); return; }
    setState(() => _carregando = true);
    try {
      _idCondominioGerado = const Uuid().v4().substring(0, 6).toUpperCase();
      final resultado = await FirebaseService.criarUsuarioSaaS(email: _emailCtrl.text.trim().toLowerCase(), senha: _senhaCtrl.text.trim(), nome: _nomeCtrl.text.trim(), perfil: 'sindico', condominio: _condominioCtrl.text.trim(), idCondominio: _idCondominioGerado, telefone: _telefoneCtrl.text.trim(), aceitouTermos: _aceitouTermos, dataExpiracao: DateTime.now().add(const Duration(days: 30)), servicoAtivo: true);
      if (!mounted) return;
      if (resultado['sucesso'] == true) {
        try { await FirebaseFirestore.instance.collection('usuarios').doc(_emailCtrl.text.trim().toLowerCase()).update({'cpf_cnpj': _cpfCnpjCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '')}); } catch(_) {}
        await _limparRascunho();
        setState(() { _etapa = 2; _carregando = false; });
      } else { setState(() => _carregando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(resultado['erro'])), backgroundColor: Colors.red)); }
    } catch (e) { setState(() => _carregando = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Novo Condomínio", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Center(child: SingleChildScrollView(child: FittedBox(fit: BoxFit.scaleDown, child: Container(width: 450, padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest.withValues(alpha:0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: colorScheme.primary.withValues(alpha:0.3))), child: _etapa == 0 ? _buildFormulario(colorScheme) : _etapa == 1 ? _buildValidacaoEmail(colorScheme) : _buildSucesso(colorScheme))))),
    );
  }

  Widget _buildFormulario(ColorScheme colorScheme) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(Icons.domain_add, size: 40, color: colorScheme.primary), const SizedBox(width: 15), const Expanded(child: Text("Crie sua conta Síndico", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))]), const SizedBox(height: 5), Text("Você terá 30 dias de teste grátis com todos os módulos liberados.", style: TextStyle(color: colorScheme.onSurfaceVariant)), const Divider(height: 30),
    TextField(controller: _condominioCtrl, decoration: const InputDecoration(labelText: "Nome do Condomínio *", border: OutlineInputBorder())), const SizedBox(height: 15),
    TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: "Seu Nome (Síndico/Gestor) *", border: OutlineInputBorder())), const SizedBox(height: 15),
    TextField(controller: _cpfCnpjCtrl, keyboardType: TextInputType.number, inputFormatters: [DocumentoFormatter()], decoration: const InputDecoration(labelText: "CPF ou CNPJ (Para Faturamento) *", border: OutlineInputBorder())), const SizedBox(height: 15),
    TextField(controller: _telefoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefone / WhatsApp *", border: OutlineInputBorder())), const SizedBox(height: 15),
    TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "E-mail de Acesso *", border: OutlineInputBorder())), const SizedBox(height: 15),
    TextField(controller: _senhaCtrl, obscureText: _ocultarSenha, decoration: InputDecoration(labelText: "Crie uma Senha *", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_ocultarSenha ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha)))), const SizedBox(height: 15),
    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Checkbox(value: _aceitouTermos, activeColor: colorScheme.primary, onChanged: (v) => setState(() => _aceitouTermos = v!)), Expanded(child: GestureDetector(onTap: () => mostrarTermosDeUso(context), child: Text.rich(TextSpan(text: "Li e aceito os ", style: TextStyle(fontSize: 12, color: colorScheme.onSurface), children: [TextSpan(text: "Termos de Uso e Política de Privacidade LGPD.", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))]))))]), const SizedBox(height: 20),
    _carregando ? const Center(child: CircularProgressIndicator()) : LogicNeonButton(fullWidth: true, corBase: _aceitouTermos ? colorScheme.primary : Colors.grey.shade700, corBrilho: _aceitouTermos ? colorScheme.primary : Colors.grey.shade500, onPressed: _aceitouTermos ? _enviarCodigo : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Você precisa ler e aceitar os Termos de Uso antes de continuar."), backgroundColor: Colors.orange)), child: Text("CONTINUAR", style: TextStyle(color: _aceitouTermos ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)))
  ]);

  Widget _buildValidacaoEmail(ColorScheme colorScheme) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.mark_email_read, size: 60, color: colorScheme.secondary), const SizedBox(height: 20), const Text("Verifique seu E-mail", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text("Enviamos um código de 6 dígitos para:\n${_emailCtrl.text}", textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)), const SizedBox(height: 30),
    TextField(controller: _codigoDigitadoCtrl, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 10), decoration: const InputDecoration(hintText: "000000", border: OutlineInputBorder(), counterText: "")), const SizedBox(height: 30),
    _carregando ? const Center(child: CircularProgressIndicator()) : LogicNeonButton(fullWidth: true, corBase: Colors.green, corBrilho: Colors.greenAccent, onPressed: _validarECriarConta, child: const Text("VALIDAR E CRIAR CONTA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), const SizedBox(height: 15),
    TextButton(onPressed: () { _limparRascunho(); setState(() { _etapa = 0; _codigoDigitadoCtrl.clear(); }); }, child: const Text("Voltar e corrigir e-mail"))
  ]);

  Widget _buildSucesso(ColorScheme colorScheme) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.check_circle, size: 80, color: Colors.green), const SizedBox(height: 20), const Text("Condomínio Criado!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 10), const Text("Sua conta foi ativada com sucesso. Para que os moradores possam se cadastrar, forneça a eles o código abaixo:", textAlign: TextAlign.center), const SizedBox(height: 20),
    Container(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10), border: Border.all(color: colorScheme.primary)), child: Column(children: [Text("CÓDIGO DO CONDOMÍNIO:", style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)), Text(_idCondominioGerado, style: TextStyle(fontSize: 32, letterSpacing: 5, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer))])), const SizedBox(height: 30),
    LogicNeonButton(fullWidth: true, corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: () => Navigator.pop(context), child: const Text("IR PARA O LOGIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
  ]);
}
class TelaCadastroMorador extends StatefulWidget {
  const TelaCadastroMorador({super.key});
  @override
  State<TelaCadastroMorador> createState() => _TelaCadastroMoradorState();
}

class _TelaCadastroMoradorState extends State<TelaCadastroMorador> {
  int _etapa = 0; bool _carregando = false, _ocultarSenha = true, _aceitouTermos = false;
  final _idCondominioCtrl = TextEditingController(), _blocoCtrl = TextEditingController(), _apCtrl = TextEditingController(), _nomeCtrl = TextEditingController(), _telefoneCtrl = TextEditingController(), _emailCtrl = TextEditingController(), _senhaCtrl = TextEditingController(), _codigoDigitadoCtrl = TextEditingController(), _cpfCtrl = TextEditingController(), _nascimentoCtrl = TextEditingController();
  String _tipoOcupacao = "inquilino", _sindicoLocalizado = "", _nomeCondominioLocalizado = "", _codigoVerificacaoCorreto = "";
  Uint8List? _fotoBytes;

  @override
  void initState() {
    super.initState();
    _carregarRascunho();
  }

  Future<void> _carregarRascunho() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('rascunho_morador');
      if (str != null) {
        final data = jsonDecode(str);
        if (DateTime.now().millisecondsSinceEpoch - (data['timestamp'] ?? 0) < 3600000) {
          setState(() {
            _idCondominioCtrl.text = data['idCondominio'] ?? '';
            _blocoCtrl.text = data['bloco'] ?? '';
            _apCtrl.text = data['ap'] ?? '';
            _nomeCtrl.text = data['nome'] ?? '';
            _telefoneCtrl.text = data['telefone'] ?? '';
            _emailCtrl.text = data['email'] ?? '';
            _senhaCtrl.text = data['senha'] ?? '';
            _cpfCtrl.text = data['cpf'] ?? '';
            _nascimentoCtrl.text = data['nascimento'] ?? '';
            _tipoOcupacao = data['tipo_ocupacao'] ?? 'inquilino';
            _sindicoLocalizado = data['sindicoLocalizado'] ?? '';
            _nomeCondominioLocalizado = data['nomeCondominioLocalizado'] ?? '';
            _codigoVerificacaoCorreto = data['codigoVerificacaoCorreto'] ?? '';
            _aceitouTermos = true;
            _etapa = 1;
          });
          final file = File('${(await getApplicationDocumentsDirectory()).path}/rasc_foto_m.jpg');
          if (await file.exists()) {
            setState(() => _fotoBytes = file.readAsBytesSync());
          }
        } else {
          _limparRascunho();
        }
      }
    } catch (_) {}
  }

  Future<void> _salvarRascunho() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('rascunho_morador', jsonEncode({
        'idCondominio': _idCondominioCtrl.text, 'bloco': _blocoCtrl.text, 'ap': _apCtrl.text,
        'nome': _nomeCtrl.text, 'telefone': _telefoneCtrl.text, 'email': _emailCtrl.text,
        'senha': _senhaCtrl.text, 'cpf': _cpfCtrl.text, 'nascimento': _nascimentoCtrl.text,
        'tipo_ocupacao': _tipoOcupacao, 'sindicoLocalizado': _sindicoLocalizado,
        'nomeCondominioLocalizado': _nomeCondominioLocalizado, 'codigoVerificacaoCorreto': _codigoVerificacaoCorreto,
        'timestamp': DateTime.now().millisecondsSinceEpoch
      }));
      if (_fotoBytes != null) {
        final file = File('${(await getApplicationDocumentsDirectory()).path}/rasc_foto_m.jpg');
        await file.writeAsBytes(_fotoBytes!);
      }
    } catch (_) {}
  }

  Future<void> _limparRascunho() async {
    try {
      (await SharedPreferences.getInstance()).remove('rascunho_morador');
      final file = File('${(await getApplicationDocumentsDirectory()).path}/rasc_foto_m.jpg');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  @override
  void dispose() { _idCondominioCtrl.dispose(); _blocoCtrl.dispose(); _apCtrl.dispose(); _nomeCtrl.dispose(); _telefoneCtrl.dispose(); _emailCtrl.dispose(); _senhaCtrl.dispose(); _codigoDigitadoCtrl.dispose(); _cpfCtrl.dispose(); _nascimentoCtrl.dispose(); super.dispose(); }

  void _mostrarErro(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

  Future<void> _enviarCodigo() async {
    if ([_idCondominioCtrl, _blocoCtrl, _apCtrl, _nomeCtrl, _emailCtrl, _senhaCtrl].any((c) => c.text.trim().isEmpty)) { _mostrarErro("Preencha todos os campos obrigatórios."); return; }
    if (_senhaCtrl.text.length < 6) { _mostrarErro("A senha deve ter pelo menos 6 caracteres."); return; }
    if (!_aceitouTermos) { _mostrarErro("Você precisa aceitar os Termos de Uso."); return; }
    setState(() => _carregando = true);
    final resposta = await HelperEmail.enviarCodigo(emailDestino: _emailCtrl.text.trim().toLowerCase(), nome: _nomeCtrl.text.trim(), perfil: 'morador', idCondominio: _idCondominioCtrl.text.trim());
    if (resposta['status'] == 'sucesso') {
      setState(() { _sindicoLocalizado = resposta['sindico_vinculado']; _nomeCondominioLocalizado = resposta['nome_condominio']; _codigoVerificacaoCorreto = resposta['codigo_gerado']; _etapa = 1; _carregando = false; });
      await _salvarRascunho();
    } else { setState(() => _carregando = false); if (mounted) _mostrarErro(TratamentoDeErros.traduzir(resposta['erro'] ?? "Erro ao enviar e-mail.")); }
  }

  Future<void> _validarECriarConta() async {
    if (_codigoDigitadoCtrl.text.trim() != _codigoVerificacaoCorreto) return _mostrarErro("Código incorreto. Verifique o e-mail.");
    setState(() => _carregando = true);
    try {
      final resultado = await FirebaseService.criarUsuarioSaaS(email: _emailCtrl.text.trim().toLowerCase(), senha: _senhaCtrl.text.trim(), nome: _nomeCtrl.text.trim().toUpperCase(), perfil: 'morador', idCondominio: _idCondominioCtrl.text.trim().toUpperCase(), sindicoVinculado: _sindicoLocalizado, bloco: _blocoCtrl.text.trim().toUpperCase(), ap: _apCtrl.text.trim(), telefone: _telefoneCtrl.text.trim(), aceitouTermos: _aceitouTermos, servicoAtivo: false);
      if (!mounted) return;
      if (resultado['sucesso'] == true) {
        try { await FirebaseFunctions.instance.httpsCallable('completarCadastroMorador').call({'email': _emailCtrl.text.trim().toLowerCase(), 'sindico': _sindicoLocalizado, 'cpf': _tipoOcupacao == 'proprietario' ? _cpfCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '') : '', 'data_nascimento': _nascimentoCtrl.text.trim(), 'tipo_ocupacao': _tipoOcupacao, 'foto_base64': base64Encode(_fotoBytes!)}); } catch (_) {}
        await _limparRascunho();
        setState(() { _etapa = 2; _carregando = false; });
      } else { setState(() => _carregando = false); _mostrarErro(TratamentoDeErros.traduzir(resultado['erro'])); }
    } catch (e) { setState(() => _carregando = false); if (mounted) _mostrarErro(TratamentoDeErros.traduzir(e)); }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Cadastro de Morador", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Center(child: SingleChildScrollView(child: FittedBox(fit: BoxFit.scaleDown, child: Container(width: 450, padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest.withValues(alpha:0.5), borderRadius: BorderRadius.circular(20), border: Border.all(color: colorScheme.primary.withValues(alpha:0.3))), child: _etapa == 0 ? _buildFormulario(colorScheme) : _etapa == 1 ? _buildValidacaoEmail(colorScheme) : _buildSucesso(colorScheme))))),
    );
  }

  Widget _buildFormulario(ColorScheme colorScheme) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(Icons.person_add, size: 40, color: colorScheme.primary), const SizedBox(width: 15), const Expanded(child: Text("Sou Morador", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))]), const SizedBox(height: 5), Text("Preencha seus dados. O seu acesso será liberado após a aprovação da administração.", style: TextStyle(color: colorScheme.onSurfaceVariant)), const Divider(height: 30),
    TextField(controller: _idCondominioCtrl, decoration: InputDecoration(labelText: "Código do Condomínio *", border: const OutlineInputBorder(), filled: true, fillColor: colorScheme.primary.withValues(alpha:0.05), helperText: "Solicite este código ao seu Síndico ou Portaria."), inputFormatters: [UpperCaseTextFormatter()]), const SizedBox(height: 15),
    Row(children: [Expanded(child: TextField(controller: _blocoCtrl, decoration: const InputDecoration(labelText: "Bloco *", border: OutlineInputBorder()), inputFormatters: [UpperCaseTextFormatter()])), const SizedBox(width: 10), Expanded(child: TextField(controller: _apCtrl, decoration: const InputDecoration(labelText: "Apartamento *", border: OutlineInputBorder())))]), const SizedBox(height: 15),
    TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: "Seu Nome Completo *", border: OutlineInputBorder()), inputFormatters: [UpperCaseTextFormatter()]), const SizedBox(height: 15),
    Row(children: [Expanded(child: TextField(controller: _nascimentoCtrl, keyboardType: TextInputType.datetime, decoration: const InputDecoration(labelText: "Data Nasc. *", hintText: "DD/MM/AAAA", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(controller: _telefoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "WhatsApp *", border: OutlineInputBorder())))]), const SizedBox(height: 15),
    // ignore: deprecated_member_use
    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(5)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Qual a sua relação com o imóvel?", style: TextStyle(fontWeight: FontWeight.bold)), Row(children: [Expanded(child: RadioListTile<String>(title: const Text("Sou Inquilino", style: TextStyle(fontSize: 13)), value: "inquilino", groupValue: _tipoOcupacao, activeColor: colorScheme.primary, contentPadding: EdgeInsets.zero, onChanged: (v) => setState(() => _tipoOcupacao = v!))), Expanded(child: RadioListTile<String>(title: const Text("Sou Proprietário", style: TextStyle(fontSize: 13)), value: "proprietario", groupValue: _tipoOcupacao, activeColor: colorScheme.primary, contentPadding: EdgeInsets.zero, onChanged: (v) => setState(() => _tipoOcupacao = v!)))]), if (_tipoOcupacao == 'proprietario') TextField(controller: _cpfCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Seu CPF (Responsável Financeiro)", border: OutlineInputBorder()), inputFormatters: [DocumentoFormatter()])])), const SizedBox(height: 15),
    TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "E-mail de Acesso *", border: OutlineInputBorder())), const SizedBox(height: 15),
    TextField(controller: _senhaCtrl, obscureText: _ocultarSenha, decoration: InputDecoration(labelText: "Crie uma Senha *", border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(_ocultarSenha ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _ocultarSenha = !_ocultarSenha)))), const SizedBox(height: 15),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Checkbox(value: _aceitouTermos, activeColor: colorScheme.primary, onChanged: (v) => setState(() => _aceitouTermos = v!)), Expanded(child: GestureDetector(onTap: () => mostrarTermosDeUso(context), child: Padding(padding: const EdgeInsets.only(top: 12), child: Text.rich(TextSpan(text: "Declaro sob as penas da lei que as informações de ocupação (Proprietário/Inquilino) são verdadeiras. Li e aceito os ", style: TextStyle(fontSize: 11, color: colorScheme.onSurface), children: [TextSpan(text: "Termos de Uso e Política de Privacidade LGPD.", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))])))))]), const SizedBox(height: 20),
    const Text("Biometria Facial (Controle de Acesso)", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)), child: const Text("⚠️ ATENÇÃO: Esta foto será enviada para as catracas do condomínio e NÃO poderá ser alterada depois. Retire bonés, óculos escuros e tire a foto em local bem iluminado.", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))), const SizedBox(height: 10),
    InkWell(onTap: () async { final escolha = await showDialog<int>(context: context, builder: (ctx) => AlertDialog(title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Origem da Foto")), content: const Text("Como deseja enviar a sua foto?"), actions:[TextButton.icon(icon: const Icon(Icons.folder), label: const Text("Selecionar Imagem"), onPressed: () => Navigator.pop(ctx, 1)), TextButton.icon(icon: const Icon(Icons.camera_alt), label: const Text("Tirar Foto"), onPressed: () => Navigator.pop(ctx, 2))])); if (escolha == null) return; try { if (escolha == 2) { Uint8List? bytesDaFoto; if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) { bytesDaFoto = await showDialog<Uint8List>(context: context, barrierDismissible: false, builder: (ctx) => const DialogCapturaCamera(titulo: "Tirar Selfie", forcarCameraFrontal: true)); } else { final photo = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 600, imageQuality: 50, preferredCameraDevice: CameraDevice.front); if (photo != null) bytesDaFoto = await photo.readAsBytes(); } if (bytesDaFoto != null) setState(() => _fotoBytes = bytesDaFoto); } else { final photo = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 50); if (photo != null) { final bytesFile = await photo.readAsBytes(); setState(() => _fotoBytes = bytesFile); } } } catch (_) { if (mounted) _mostrarErro("Acesso negado ou falha na câmera."); } }, child: Container(height: 120, width: double.infinity, decoration: BoxDecoration(color: _fotoBytes != null ? Colors.green.withValues(alpha:0.1) : colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10), border: Border.all(color: _fotoBytes != null ? Colors.green : colorScheme.outlineVariant), image: _fotoBytes != null ? DecorationImage(image: MemoryImage(_fotoBytes!), fit: BoxFit.cover) : null), child: _fotoBytes == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.face, size: 40, color: colorScheme.onSurfaceVariant), const SizedBox(height: 5), Text("Adicionar Foto do Rosto", style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))]) : null)), const SizedBox(height: 20),
    _carregando ? const Center(child: CircularProgressIndicator()) : LogicNeonButton(fullWidth: true, corBase: (_aceitouTermos && _fotoBytes != null) ? colorScheme.primary : Colors.grey.shade700, corBrilho: (_aceitouTermos && _fotoBytes != null) ? colorScheme.primary : Colors.grey.shade500, onPressed: (_aceitouTermos && _fotoBytes != null) ? _enviarCodigo : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Você precisa aceitar os Termos e tirar a Foto obrigatória!"), backgroundColor: Colors.orange)), child: Text("CONTINUAR", style: TextStyle(color: (_aceitouTermos && _fotoBytes != null) ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)))
  ]);

  Widget _buildValidacaoEmail(ColorScheme colorScheme) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.mark_email_read, size: 60, color: colorScheme.secondary), const SizedBox(height: 20), const Text("Verifique seu E-mail", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text("Enviamos um código de 6 dígitos para:\n${_emailCtrl.text}", textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onSurfaceVariant)), const SizedBox(height: 30), TextField(controller: _codigoDigitadoCtrl, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 10), decoration: const InputDecoration(hintText: "000000", border: OutlineInputBorder(), counterText: "")), const SizedBox(height: 30), _carregando ? const Center(child: CircularProgressIndicator()) : LogicNeonButton(fullWidth: true, corBase: Colors.green, corBrilho: Colors.greenAccent, onPressed: _validarECriarConta, child: const Text("VALIDAR E CONCLUIR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))), const SizedBox(height: 15), TextButton(onPressed: () { _limparRascunho(); setState(() { _etapa = 0; _codigoDigitadoCtrl.clear(); }); }, child: const Text("Voltar e corrigir dados"))]);
  Widget _buildSucesso(ColorScheme colorScheme) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.how_to_reg, size: 80, color: Colors.orange), const SizedBox(height: 20), const Text("Cadastro Recebido!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Text("Você está vinculado ao condomínio:\n$_nomeCondominioLocalizado", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 20), const Text("Por questões de segurança, sua conta encontra-se em status PENDENTE. Você já pode fazer o login no aplicativo, mas as funcionalidades só serão liberadas após a administração confirmar seus dados.", textAlign: TextAlign.center), const SizedBox(height: 30), LogicNeonButton(fullWidth: true, corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: () => Navigator.pop(context), child: const Text("IR PARA O LOGIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]);
}

// ============================================================================
// PARTE 9 - COMUNICAÇÃO E AVISOS (SOCIAL)
// ============================================================================

class TelaNotificacoes extends StatefulWidget {
  final String emailSindico, perfil, emailUsuario;
  const TelaNotificacoes({super.key, required this.emailSindico, required this.perfil, required this.emailUsuario});
  @override
  State<TelaNotificacoes> createState() => _TelaNotificacoesState();
}

class _TelaNotificacoesState extends State<TelaNotificacoes> with WidgetsBindingObserver {
  late Stream<QuerySnapshot> _historicoNotificacoesStream;
  int _limiteNotificacoes = 20;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _initStreams(); }
  void _initStreams() { _historicoNotificacoesStream = FirebaseFirestore.instance.collection('notificacoes').where('sindico_vinculado', isEqualTo: widget.emailSindico).orderBy('data', descending: true).limit(_limiteNotificacoes).snapshots(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) FirebaseAuth.instance.currentUser?.getIdToken(true); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Central de Comunicados"), actions: const [BotaoTrocarTema()]),
      floatingActionButton: FloatingActionButton.extended(key: keyTutNotNovo, onPressed: () => showDialog(context: context, barrierDismissible: false, builder: (ctx) => _ModalNovoAviso(emailSindico: widget.emailSindico)), icon: const Icon(Icons.add_alert), label: const Text("Novo Aviso", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.all(20), child: Text("Histórico de Avisos Enviados", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: _historicoNotificacoesStream, builder: (context, snap) {
          if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: SelectableText("O Firebase exige um Índice para esta consulta com limite.\n\nCopie o link gerado abaixo e cole no seu navegador para o Firebase criar a regra automaticamente:\n\n${snap.error}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center)));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          var docs = snap.data!.docs.toList();
          if (widget.perfil == 'porteiro') {
            docs = docs.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final remetente = (data['remetente'] ?? '').toString();
              final titulo = (data['titulo'] ?? '').toString().toLowerCase();
              if (remetente.contains('Sistema de Ronda') || titulo.contains('fatura') || titulo.contains('boleto')) return false;
              return true;
            }).toList();
          }
          docs.sort((a, b) => ((b.data() as Map)['data'] ?? Timestamp.now()).compareTo((a.data() as Map)['data'] ?? Timestamp.now()));
          if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.campaign, size: 80, color: colorScheme.onSurfaceVariant.withValues(alpha:0.3)), const SizedBox(height: 20), Text("Nenhum aviso foi enviado ainda.", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16))]));
          return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), itemCount: docs.length + 1, itemBuilder: (ctx, i) {
            if (i == docs.length) return Padding(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20), child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(15)), icon: const Icon(Icons.history), label: Text("CARREGAR MAIS ANTIGOS (Mostrando os últimos $_limiteNotificacoes)"), onPressed: () => setState(() { _limiteNotificacoes += 20; _initStreams(); })));
            final doc = docs[i], data = doc.data() as Map<String, dynamic>, destino = data['para'] ?? 'todos', paraTodos = destino == 'todos', paraBloco = destino.startsWith('bloco_'), labelDestino = paraTodos ? "🚨 GERAL (Todos)" : (paraBloco ? "🏢 BLOCO ${destino.split('_')[1]}" : "🔒 PRIVADO (${data['nome_destino'] ?? destino})"), dataFormatada = data['data'] != null ? DateFormat('dd/MM/yyyy HH:mm').format((data['data'] as Timestamp).toDate()) : "Agora";
            return Card(margin: const EdgeInsets.only(bottom: 15), elevation: 2, shape: RoundedRectangleBorder(side: BorderSide(color: paraTodos ? colorScheme.primary.withValues(alpha:0.3) : colorScheme.secondary.withValues(alpha:0.3)), borderRadius: BorderRadius.circular(10)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: paraTodos ? colorScheme.primaryContainer : colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(5)), child: Text(labelDestino, style: TextStyle(color: paraTodos ? colorScheme.onPrimaryContainer : colorScheme.onSecondaryContainer, fontSize: 10, fontWeight: FontWeight.bold))))), const SizedBox(width: 10), Text(dataFormatada, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12))]), const SizedBox(height: 15), Text(data['titulo'] ?? 'Sem Título', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 8), Text(data['mensagem'] ?? '', style: TextStyle(color: colorScheme.onSurface.withValues(alpha:0.9), fontSize: 15)), const Divider(height: 30),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.person, size: 14, color: colorScheme.onSurfaceVariant), const SizedBox(width: 5), Expanded(child: Text("Enviado por: ${data['remetente'] ?? 'Sistema'}", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)))])), IconButton(icon: Icon(Icons.delete, color: colorScheme.error, size: 20), padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: "Apagar Aviso", onPressed: () { showDialog(context: context, builder: (c) => AlertDialog(title: Text("Apagar Aviso?", style: TextStyle(color: colorScheme.error)), content: const Text("Este aviso sumirá do mural de todos os moradores. Confirma?"), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError), onPressed: () async { await doc.reference.delete(); if (mounted) Navigator.pop(c); }, child: const Text("APAGAR"))])); })])
            ])));
          });
        }))
      ]),
    );
  }
}

class _ModalNovoAviso extends StatefulWidget {
  final String emailSindico;
  const _ModalNovoAviso({required this.emailSindico});
  @override
  State<_ModalNovoAviso> createState() => _ModalNovoAvisoState();
}

class _ModalNovoAvisoState extends State<_ModalNovoAviso> {
  int _etapaAtual = 0; String _tipoDestino = "todos"; String? _blocoSelecionado, _apSelecionado, _emailMoradorSelecionado;
  final _tituloCtrl = TextEditingController(), _mensagemCtrl = TextEditingController(); bool _enviando = false, _carregandoBlocos = false;
  List<String> _listaBlocos = [], _listaAps = []; List<Map<String, dynamic>> _listaMoradoresDoAp = [];

  @override
  void dispose() { _tituloCtrl.dispose(); _mensagemCtrl.dispose(); super.dispose(); }

  Future<void> _carregarBlocos() async {
    setState(() => _carregandoBlocos = true);
    try { _listaBlocos = (await FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('perfil', isEqualTo: 'morador').where('status', isEqualTo: 'aprovado').get()).docs.map((d) => (d.data()['bloco'] ?? '').toString().toUpperCase()).toSet().toList()..sort(); } catch (_) {}
    setState(() => _carregandoBlocos = false);
  }

  Future<void> _carregarApsDoBloco(String bloco) async {
    final snap = await FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('perfil', isEqualTo: 'morador').where('status', isEqualTo: 'aprovado').where('bloco', isEqualTo: bloco).get();
    setState(() { _listaAps = snap.docs.map((d) => (d.data()['ap'] ?? '').toString()).toSet().toList()..sort(); _apSelecionado = null; _emailMoradorSelecionado = null; _listaMoradoresDoAp = []; });
  }

  Future<void> _carregarMoradoresDoAp(String ap) async {
    final snap = await FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('perfil', isEqualTo: 'morador').where('status', isEqualTo: 'aprovado').where('bloco', isEqualTo: _blocoSelecionado).where('ap', isEqualTo: ap).get();
    setState(() { _listaMoradoresDoAp = snap.docs.map((d) => {'nome': d.data()['nome'], 'email': d.data()['email'] ?? d.id}).toList(); _emailMoradorSelecionado = null; });
  }

  void _avancarEtapa() {
    if (_etapaAtual == 0) { if (_tipoDestino == "todos") setState(() => _etapaAtual = 2); else { _carregarBlocos(); setState(() => _etapaAtual = 1); } }
    else if (_etapaAtual == 1) {
      if (_tipoDestino == 'bloco' && _blocoSelecionado == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione um Bloco!"))); return; }
      if (_tipoDestino == 'morador' && _emailMoradorSelecionado == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione o Morador!"))); return; }
      setState(() => _etapaAtual = 2);
    }
  }

  void _voltarEtapa() { if (_etapaAtual == 2) setState(() => _etapaAtual = _tipoDestino == "todos" ? 0 : 1); else if (_etapaAtual == 1) setState(() => _etapaAtual = 0); }

  Future<void> _enviarNotificacao() async {
    if (_tituloCtrl.text.trim().isEmpty || _mensagemCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha o Título e a Mensagem!"), backgroundColor: Colors.red)); return; }
    setState(() => _enviando = true);
    try {
      String destinoFinal = "todos"; final emailsAlvo = <String>[];
      if (_tipoDestino == "morador") destinoFinal = _emailMoradorSelecionado!; else if (_tipoDestino == "bloco") { destinoFinal = "bloco_$_blocoSelecionado"; emailsAlvo.addAll((await FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('perfil', isEqualTo: 'morador').where('bloco', isEqualTo: _blocoSelecionado).get()).docs.map((d) => d.data()['email'] ?? d.id).cast<String>()); }
      final batch = FirebaseFirestore.instance.batch();
      String nomeDest = _tipoDestino == "morador" ? "Bloco $_blocoSelecionado AP $_apSelecionado - ${_listaMoradoresDoAp.firstWhere((m) => m['email'] == _emailMoradorSelecionado)['nome'] ?? ''}" : destinoFinal;
      batch.set(FirebaseFirestore.instance.collection('notificacoes').doc(), {'sindico_vinculado': widget.emailSindico, 'para': destinoFinal, 'nome_destino': nomeDest, 'titulo': _tituloCtrl.text.trim(), 'mensagem': _mensagemCtrl.text.trim(), 'data': FieldValue.serverTimestamp(), 'remetente': operadorLogado, 'tipo_acao': 'acao_avisos'});
      if (_tipoDestino == "bloco" && emailsAlvo.isNotEmpty) for (final email in emailsAlvo) batch.set(FirebaseFirestore.instance.collection('notificacoes').doc(), {'sindico_vinculado': widget.emailSindico, 'para': email, 'nome_destino': nomeDest, 'titulo': _tituloCtrl.text.trim(), 'mensagem': _mensagemCtrl.text.trim(), 'data': FieldValue.serverTimestamp(), 'remetente': operadorLogado, 'tipo_acao': 'acao_avisos', 'ocultar_do_historico': true});
      await batch.commit(); if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Comunicado disparado com sucesso!"), backgroundColor: Colors.green)); }
    } catch (e) { setState(() => _enviando = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(children: [Icon(Icons.campaign, color: colorScheme.primary), const SizedBox(width: 10), const Text("Novo Aviso")]),
      content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ignore: deprecated_member_use
        if (_etapaAtual == 0) ...[const Text("Quem deve receber este comunicado?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 15), RadioListTile<String>(title: const Text("Todo o Condomínio"), subtitle: const Text("Aparece no mural de todos."), value: "todos", groupValue: _tipoDestino, activeColor: colorScheme.primary, onChanged: (v) => setState(() => _tipoDestino = v!)), RadioListTile<String>(title: const Text("Um Bloco Específico"), subtitle: const Text("Apenas moradores de um bloco."), value: "bloco", groupValue: _tipoDestino, activeColor: colorScheme.primary, onChanged: (v) => setState(() => _tipoDestino = v!)), RadioListTile<String>(title: const Text("Morador Específico"), subtitle: const Text("Mensagem privada para um apartamento."), value: "morador", groupValue: _tipoDestino, activeColor: colorScheme.primary, onChanged: (v) => setState(() => _tipoDestino = v!))],
        if (_etapaAtual == 1) ...[if (_carregandoBlocos) const Center(child: CircularProgressIndicator()) else if (_listaBlocos.isEmpty) const Text("Nenhum morador aprovado no condomínio.", style: TextStyle(color: Colors.red)) else ...[const Text("Selecione o Bloco:", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), DropdownButtonFormField<String>(isExpanded: true, decoration: const InputDecoration(border: OutlineInputBorder()), hint: const Text("Escolha um Bloco"), initialValue: _blocoSelecionado, items: _listaBlocos.map((b) => DropdownMenuItem(value: b, child: Text("Bloco $b"))).toList(), onChanged: (v) { setState(() => _blocoSelecionado = v!); if (_tipoDestino == "morador") _carregarApsDoBloco(v!); }), if (_tipoDestino == "morador" && _blocoSelecionado != null) ...[const SizedBox(height: 15), const Text("Selecione o Apartamento:", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), DropdownButtonFormField<String>(isExpanded: true, decoration: const InputDecoration(border: OutlineInputBorder()), hint: const Text("Escolha um AP"), initialValue: _apSelecionado, items: _listaAps.map((a) => DropdownMenuItem(value: a, child: Text("AP $a"))).toList(), onChanged: (v) { setState(() => _apSelecionado = v!); _carregarMoradoresDoAp(v!); })], if (_tipoDestino == "morador" && _apSelecionado != null) ...[const SizedBox(height: 15), const Text("Selecione o Morador:", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), if (_listaMoradoresDoAp.isEmpty) const Text("Buscando moradores...", style: TextStyle(color: Colors.grey)) else DropdownButtonFormField<String>(isExpanded: true, decoration: const InputDecoration(border: OutlineInputBorder()), hint: const Text("Quem vai receber?"), initialValue: _emailMoradorSelecionado, items: _listaMoradoresDoAp.map((m) => DropdownMenuItem(value: m['email'] as String, child: Text(m['nome']))).toList(), onChanged: (v) => setState(() => _emailMoradorSelecionado = v!))]]],
        if (_etapaAtual == 2) ...[Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(5)), child: Row(children: [Icon(Icons.info, color: colorScheme.primary, size: 16), const SizedBox(width: 8), Expanded(child: Text(_tipoDestino == "todos" ? "Enviando para TODOS os moradores" : _tipoDestino == "bloco" ? "Enviando para o BLOCO $_blocoSelecionado" : "Mensagem Privada (Oculto no mural de outros)", style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 12)))])), const SizedBox(height: 20), TextField(controller: _tituloCtrl, decoration: const InputDecoration(labelText: "Título do Aviso", border: OutlineInputBorder()), maxLength: 50, textCapitalization: TextCapitalization.sentences), const SizedBox(height: 10), TextField(controller: _mensagemCtrl, decoration: const InputDecoration(labelText: "Mensagem detalhada", border: OutlineInputBorder()), maxLines: 4, maxLength: 300, textCapitalization: TextCapitalization.sentences)]
      ]))),
      actions: [if (_etapaAtual == 0) TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))) else TextButton(onPressed: _voltarEtapa, child: const Text("VOLTAR")), if (_etapaAtual < 2) ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: _avancarEtapa, child: const Text("AVANÇAR")) else ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), icon: _enviando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send, size: 18), label: Text(_enviando ? "ENVIANDO..." : "DISPARAR AVISO"), onPressed: _enviando ? null : _enviarNotificacao)]
    );
  }
}

// ============================================================================
// PARTE 10 - RESERVAS E ÁREAS COMUNS (COMODIDADES) E LGPD
// ============================================================================

class TelaReservasAdmin extends StatefulWidget {
  final String emailSindico, perfil;
  const TelaReservasAdmin({super.key, required this.emailSindico, required this.perfil});
  @override
  State<TelaReservasAdmin> createState() => _TelaReservasAdminState();
}

class _TelaReservasAdminState extends State<TelaReservasAdmin> with WidgetsBindingObserver {
  String _filtroStatus = 'all'; DateTime? _dataFiltroInicio, _dataFiltroFim;
  late Stream<QuerySnapshot> _areasStream, _reservasHojeStream, _filaStream;
  List<Map<String, dynamic>> _reservasCache = [];
  bool _carregandoReservas = true, _buscandoNuvemReservas = false, _fimDaListaReservas = false;
  final ScrollController _scrollControllerReservas = ScrollController();
  StreamSubscription<QuerySnapshot>? _novasReservasSub;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _scrollControllerReservas.addListener(_aoRolarTelaReservas); _initStreams(); _carregarReservasDeltaSync(); }

  void _aoRolarTelaReservas() { if (_scrollControllerReservas.position.pixels >= _scrollControllerReservas.position.maxScrollExtent - 200 && !_buscandoNuvemReservas && !_fimDaListaReservas && _filtroStatus != 'fila') _buscarMaisAntigosNaNuvemReservas(); }

  void _initStreams() {
    final dataHoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _areasStream = FirebaseFirestore.instance.collection('areas_comuns').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots();
    _reservasHojeStream = FirebaseFirestore.instance.collection('reservas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('data_reserva', isEqualTo: dataHoje).where('status', isEqualTo: 'confirmada').snapshots();
    _filaStream = FirebaseFirestore.instance.collection('fila_espera').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _reconectarBancoDeDados(); }
  Future<void> _reconectarBancoDeDados() async { try { await FirebaseAuth.instance.currentUser?.getIdToken(true); setState(() { _initStreams(); _carregarReservasDeltaSync(); }); } catch (_) {} }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _scrollControllerReservas.dispose(); _novasReservasSub?.cancel(); super.dispose(); }

  Future<void> _salvarCacheReservas(List<Map<String, dynamic>> lista) async {
    try {
      final jsonStr = jsonEncode(lista.map((item) => item.map((k, v) => MapEntry(k, v is Timestamp ? v.toDate().toIso8601String() : v))).toList());
      if (kIsWeb) await (await SharedPreferences.getInstance()).setString('reservas_delta_${widget.emailSindico}', jsonStr);
      else await File('${(await getApplicationDocumentsDirectory()).path}/reservas_delta_${widget.emailSindico}.json').writeAsString(jsonStr);
    } catch (_) {}
  }

  Future<void> _carregarReservasDeltaSync() async {
    try {
      String jsonString = ""; if (kIsWeb) jsonString = (await SharedPreferences.getInstance()).getString('reservas_delta_${widget.emailSindico}') ?? ""; else { final file = File('${(await getApplicationDocumentsDirectory()).path}/reservas_delta_${widget.emailSindico}.json'); if (await file.exists()) jsonString = await file.readAsString(); }
      if (jsonString.isNotEmpty) _reservasCache = (jsonDecode(jsonString) as List).map((item) => Map<String, dynamic>.from(item)).toList();
      if (mounted) setState(() => _carregandoReservas = false);

      String? ultimaDataReserva; final comData = _reservasCache.where((m) => m['data_reserva'] != null).toList();
      if (comData.isNotEmpty) { comData.sort((a, b) => (b['data_reserva'] as String).compareTo(a['data_reserva'] as String)); ultimaDataReserva = comData.first['data_reserva'] as String; }

      if (ultimaDataReserva == null) {
        if (mounted) setState(() => _buscandoNuvemReservas = true);
        for (var doc in (await FirebaseFirestore.instance.collection('reservas').where('sindico_vinculado', isEqualTo: widget.emailSindico).orderBy('data_reserva', descending: true).limit(30).get()).docs) _reservasCache.add(doc.data()..['id'] = doc.id);
        if (mounted) setState(() => _buscandoNuvemReservas = false); await _salvarCacheReservas(_reservasCache);
      } else {
        final snapNovos = await FirebaseFirestore.instance.collection('reservas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('data_reserva', isGreaterThan: ultimaDataReserva).get();
        if (snapNovos.docs.isNotEmpty) { for (var doc in snapNovos.docs) _reservasCache.insert(0, doc.data()..['id'] = doc.id); _reservasCache.sort((a, b) => (b['data_reserva'] as String).compareTo(a['data_reserva'] as String)); if (mounted) setState(() {}); await _salvarCacheReservas(_reservasCache); }
      }

      _novasReservasSub?.cancel();
      _novasReservasSub = FirebaseFirestore.instance.collection('reservas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('data_reserva', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 2)))).snapshots().listen((snap) {
        bool alterou = false;
        for (var change in snap.docChanges) { final data = change.doc.data()!..['id'] = change.doc.id; final idx = _reservasCache.indexWhere((v) => v['id'] == change.doc.id); if (change.type == DocumentChangeType.added || change.type == DocumentChangeType.modified) { if (idx != -1) _reservasCache[idx] = data; else _reservasCache.insert(0, data); alterou = true; } else if (change.type == DocumentChangeType.removed && idx != -1) { _reservasCache.removeAt(idx); alterou = true; } }
        if (alterou) { _reservasCache.sort((a, b) => ((b['data_reserva'] ?? '') as String).compareTo((a['data_reserva'] ?? '') as String)); if (mounted) setState(() {}); _salvarCacheReservas(_reservasCache); }
      });
    } catch (e) { if (mounted) setState(() => _carregandoReservas = false); if (e.toString().contains('index') && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("O Firebase precisa criar um índice de busca para as Reservas. Verifique o console."), backgroundColor: Colors.red, duration: Duration(seconds: 8))); }
  }

  Future<void> _buscarMaisAntigosNaNuvemReservas() async {
    setState(() => _buscandoNuvemReservas = true);
    try {
      final comData = _reservasCache.where((m) => m['data_reserva'] != null).toList()..sort((a, b) => (b['data_reserva'] as String).compareTo(a['data_reserva'] as String));
      final dataMaisVelha = comData.isNotEmpty ? comData.last['data_reserva'] as String : null;
      if (dataMaisVelha != null) {
        final snap = await FirebaseFirestore.instance.collection('reservas').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('data_reserva', isLessThan: dataMaisVelha).orderBy('data_reserva', descending: true).limit(20).get();
        if (snap.docs.isNotEmpty) { for (var doc in snap.docs) { final data = doc.data()..['id'] = doc.id; if (!_reservasCache.any((m) => m['id'] == doc.id)) _reservasCache.add(data); } if (mounted) setState(() {}); _salvarCacheReservas(_reservasCache); } else _fimDaListaReservas = true;
      }
    } catch (_) {}
    if (mounted) setState(() => _buscandoNuvemReservas = false);
  }

  Future<void> _selecionarDataFiltro(BuildContext context) async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now().add(const Duration(days: 365)), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme), child: child!));
    if (picked != null) setState(() { _dataFiltroInicio = picked.start; _dataFiltroFim = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59); });
  }

  void _novaArea() {
    String nome = "", regras = ""; int antecedencia = 30; double taxaUso = 0.0; bool tIntegral = true, tAlmoco = false, tJantar = false, processando = false;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const FittedBox(fit: BoxFit.scaleDown, child: Text("Configurar Área Comum")),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children:[
          TextField(onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: "Nome (Ex: Salão de Festas)")), TextField(onChanged: (v) => regras = v, maxLines: 4, decoration: const InputDecoration(labelText: "Regras de Uso e Observações (Termos)")), const SizedBox(height: 10),
          Row(children: [Expanded(child: TextField(onChanged: (v) => antecedencia = int.tryParse(v) ?? 30, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Antecedência (Dias)"))), const SizedBox(width: 10), Expanded(child: TextField(onChanged: (v) => taxaUso = double.tryParse(v.replaceAll(',', '.')) ?? 0.0, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Taxa de Uso (R\$)", helperText: "0 = Grátis")))]), const SizedBox(height: 15),
          const Text("Turnos Disponíveis para Aluguel:", style: TextStyle(fontWeight: FontWeight.bold)), CheckboxListTile(title: const Text("Dia Integral"), value: tIntegral, activeColor: colorScheme.primary, onChanged: (v) => setStateSB(() => tIntegral = v!)), CheckboxListTile(title: const Text("Almoço (Manhã/Tarde)"), value: tAlmoco, activeColor: colorScheme.primary, onChanged: (v) => setStateSB(() => tAlmoco = v!)), CheckboxListTile(title: const Text("Jantar (Noite)"), value: tJantar, activeColor: colorScheme.primary, onChanged: (v) => setStateSB(() => tJantar = v!))
        ])),
        actions:[
          if (!processando) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: processando ? null : () async {
            if (nome.isNotEmpty && regras.isNotEmpty) {
              final turnos = <String>[]; if (tIntegral) turnos.add("Integral"); if (tAlmoco) turnos.add("Almoço"); if (tJantar) turnos.add("Jantar");
              if (turnos.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione pelo menos um turno."))); return; }
              setStateSB(() => processando = true);
              try { await FirebaseFirestore.instance.collection('areas_comuns').add({'sindico_vinculado': widget.emailSindico, 'nome': nome, 'regras': regras, 'dias_antecedencia': antecedencia, 'valor_taxa': taxaUso, 'turnos': turnos, 'criado_em': FieldValue.serverTimestamp()}); if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Área criada com sucesso!"), backgroundColor: Colors.green)); } } catch (e) { setStateSB(() => processando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); }
            } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha o Nome e as Regras."))); }
          }, child: processando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SALVAR ÁREA"))
        ]
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final isSindico = widget.perfil == 'sindico', colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: isSindico ? FloatingActionButton.extended(key: keyTutResNova, onPressed: _novaArea, icon: const Icon(Icons.add_location_alt), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("Criar Área"))) : null,
      body: Column(children:[
        const Padding(padding: EdgeInsets.all(16.0), child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: Text("Gestão de Áreas Comuns", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))))),
        DefaultTabController(length: isSindico ? 3 : 1, child: Expanded(child: Column(children:[TabBar(isScrollable: true, labelColor: colorScheme.primary, unselectedLabelColor: colorScheme.onSurfaceVariant, indicatorColor: colorScheme.primary, tabs:[if (isSindico) Tab(key: keyTutResAba1, text: "Áreas Configuradas"), Tab(key: keyTutResAba2, text: "Reservas de Hoje (Portaria)"), if (isSindico) Tab(key: keyTutResAba3, text: "Histórico e Filas")]), Expanded(child: TabBarView(children:[if (isSindico) _abaAreas(), _abaPortariaHoje(), if (isSindico) _abaHistorico()]))])))
      ])
    );
  }

  Widget _abaAreas() {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(stream: _areasStream, builder: (context, snap) {
      if (snap.hasError) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.wifi_off, size: 50, color: colorScheme.error), const SizedBox(height: 15), Text("Sessão expirada ou erro de conexão.", style: TextStyle(color: colorScheme.onSurfaceVariant)), const SizedBox(height: 10), ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("Recarregar"), onPressed: _reconectarBancoDeDados)]));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhuma área cadastrada."));
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) {
        final doc = snap.data!.docs[i], data = doc.data() as Map<String, dynamic>, turnos = data['turnos'] ?? [];
        return Card(elevation: 2, margin: const EdgeInsets.only(bottom: 15), child: ListTile(leading: CircleAvatar(backgroundColor: colorScheme.primaryContainer, child: Icon(Icons.deck, color: colorScheme.primary)), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Turnos: ${turnos.join(', ')} | Antecedência mín: ${data['dias_antecedencia']} dias")), const SizedBox(height: 5), Text("Regras: ${data['regras']}", maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: colorScheme.onSurfaceVariant))]), trailing: IconButton(icon: Icon(Icons.delete, color: colorScheme.error), onPressed: () => doc.reference.delete())));
      });
    });
  }

  Widget _abaPortariaHoje() {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<QuerySnapshot>(stream: _reservasHojeStream, builder: (context, snap) {
      if (snap.hasError) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.wifi_off, size: 50, color: colorScheme.error), const SizedBox(height: 15), Text("Sessão expirada ou erro de conexão.", style: TextStyle(color: colorScheme.onSurfaceVariant)), const SizedBox(height: 10), ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("Recarregar"), onPressed: _reconectarBancoDeDados)]));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhuma reserva confirmada para hoje."));
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) {
        final data = snap.data!.docs[i].data() as Map<String, dynamic>;
        return Card(color: Colors.green.withValues(alpha:0.1), shape: RoundedRectangleBorder(side: BorderSide(color: Colors.green.withValues(alpha:0.5)), borderRadius: BorderRadius.circular(10)), child: ListTile(leading: const Icon(Icons.event_available, color: Colors.green, size: 40), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data['nome_area'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))), subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Turno: ${data['turno']}\nMorador: ${data['morador']} (Bloco ${data['bloco']} AP ${data['ap']})", style: const TextStyle(fontSize: 15))), trailing: const FittedBox(fit: BoxFit.scaleDown, child: Text("HOJE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)))));
      });
    });
  }

  Widget _abaHistorico() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(children:[
      Padding(padding: const EdgeInsets.all(16), child: Wrap(spacing: 15, crossAxisAlignment: WrapCrossAlignment.center, children:[const Text("Status: ", style: TextStyle(fontWeight: FontWeight.bold)), Container(key: keyTutResFiltros, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(5)), child: DropdownButton<String>(underline: const SizedBox(), value: _filtroStatus, items: const[DropdownMenuItem(value: 'all', child: Text("Todas")), DropdownMenuItem(value: 'confirmada', child: Text("Confirmadas")), DropdownMenuItem(value: 'cancelada', child: Text("Canceladas")), DropdownMenuItem(value: 'fila', child: Text("Fila de Espera"))], onChanged: (v) => setState(() => _filtroStatus = v!))), FittedBox(fit: BoxFit.scaleDown, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: _dataFiltroInicio != null ? colorScheme.primary : colorScheme.surfaceContainerHighest, foregroundColor: _dataFiltroInicio != null ? colorScheme.onPrimary : colorScheme.onSurfaceVariant), icon: const Icon(Icons.calendar_month), label: Text(_dataFiltroInicio != null ? "${DateFormat('dd/MM').format(_dataFiltroInicio!)} - ${DateFormat('dd/MM').format(_dataFiltroFim!)}" : "Filtrar por Data"), onPressed: () => _selecionarDataFiltro(context))), if (_dataFiltroInicio != null) IconButton(icon: Icon(Icons.clear, color: colorScheme.error), onPressed: () => setState(() { _dataFiltroInicio = null; _dataFiltroFim = null; }))])),
      Expanded(child: _filtroStatus == 'fila' ? StreamBuilder<QuerySnapshot>(stream: _filaStream, builder: (context, snap) {
        if (snap.hasError) return const Center(child: Text("Erro de conexão.")); if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        var docs = snap.data!.docs.toList();
        if (_dataFiltroInicio != null) docs = docs.where((d) { try { final dt = DateTime.parse((d.data() as Map<String, dynamic>)['data_reserva']); return !(dt.isBefore(_dataFiltroInicio!) || dt.isAfter(_dataFiltroFim!)); } catch (_) { return false; } }).toList();
        if (docs.isEmpty) return const Center(child: Text("Fila de espera vazia."));
        return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: docs.length, itemBuilder: (ctx, i) {
          final data = docs[i].data() as Map<String, dynamic>; String dataExibicao = data['data_reserva'] ?? ''; try { dataExibicao = DateFormat('dd/MM/yyyy').format(DateTime.parse(dataExibicao)); } catch (_) {}
          return Card(elevation: 1, child: ListTile(leading: const Icon(Icons.hourglass_top, color: Colors.orange), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("${data['nome_area'] ?? 'Área'} - $dataExibicao", style: const TextStyle(fontWeight: FontWeight.bold))), subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Turno: ${data['turno']} | Morador: ${data['morador']} (B: ${data['bloco']} AP: ${data['ap']})")), trailing: const FittedBox(fit: BoxFit.scaleDown, child: Text("FILA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 12)))));
        });
      }) : (_carregandoReservas ? const Center(child: CircularProgressIndicator()) : Builder(builder: (context) {
        final filtrados = _reservasCache.where((data) {
          if (_filtroStatus != 'all' && data['status'] != _filtroStatus) return false;
          if (_dataFiltroInicio != null && data['data_reserva'] != null) { try { final dt = DateTime.parse(data['data_reserva']); if (dt.isBefore(_dataFiltroInicio!) || dt.isAfter(_dataFiltroFim!)) return false; } catch (_) { return false; } } return true;
        }).toList()..sort((a, b) => (b['data_reserva'] ?? '').compareTo(a['data_reserva'] ?? ''));
        if (filtrados.isEmpty) return const Center(child: Text("Nenhum registro encontrado."));
        return ListView.builder(controller: _scrollControllerReservas, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: filtrados.length + (_buscandoNuvemReservas ? 1 : 0), itemBuilder: (ctx, i) {
          if (i == filtrados.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Buscando histórico na nuvem...", style: TextStyle(color: Colors.grey))])));
          final data = filtrados[i], isCancelada = data['status'] == 'cancelada'; String dataExibicao = data['data_reserva'] ?? ''; try { dataExibicao = DateFormat('dd/MM/yyyy').format(DateTime.parse(dataExibicao)); } catch (_) {}
          final statusColor = isCancelada ? colorScheme.error : Colors.green;
          return Card(elevation: 1, child: ListTile(leading: Icon(isCancelada ? Icons.cancel : Icons.check_circle, color: statusColor), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("${data['nome_area'] ?? 'Área'} - $dataExibicao", style: const TextStyle(fontWeight: FontWeight.bold))), subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Turno: ${data['turno']} | Morador: ${data['morador']} (B: ${data['bloco']} AP: ${data['ap']})")), trailing: FittedBox(fit: BoxFit.scaleDown, child: Text(data['status'].toString().toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 12)))));
        });
      })))
    ]);
  }
}

class TelaReservasMorador extends StatefulWidget {
  final Map<String, dynamic> userData;
  const TelaReservasMorador({super.key, required this.userData});
  @override
  State<TelaReservasMorador> createState() => _TelaReservasMoradorState();
}

class _TelaReservasMoradorState extends State<TelaReservasMorador> with WidgetsBindingObserver {
  DateTime? _dataFiltroInicio, _dataFiltroFim;
  late Stream<QuerySnapshot> _areasStream, _minhasReservasStream;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _initStreams(); }

  void _initStreams() {
    _areasStream = FirebaseFirestore.instance.collection('areas_comuns').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).snapshots();
    _minhasReservasStream = FirebaseFirestore.instance.collection('reservas').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('email', isEqualTo: widget.userData['email']).snapshots();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) _reconectarBancoDeDados(); }
  Future<void> _reconectarBancoDeDados() async { try { await FirebaseAuth.instance.currentUser?.getIdToken(true); setState(() { _initStreams(); }); } catch (_) {} }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  Future<void> _selecionarDataFiltro(BuildContext context) async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now().add(const Duration(days: 365)), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme), child: child!));
    if (picked != null) setState(() { _dataFiltroInicio = picked.start; _dataFiltroFim = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59); });
  }

  Future<void> _cancelarReserva(DocumentReference refReserva, Map<String, dynamic> dadosReserva) async {
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: const Text("Cancelar Reserva?"), content: const Text("Tem certeza que deseja cancelar? O primeiro morador da fila de espera será notificado e poderá alugar a área."), actions:[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("NÃO")), LogicNeonButton(corBase: colorScheme.error, corBrilho: colorScheme.error, onPressed: () async {
        await refReserva.update({'status': 'cancelada'});
        final filaSnap = await FirebaseFirestore.instance.collection('fila_espera').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('id_area', isEqualTo: dadosReserva['id_area']).where('data_reserva', isEqualTo: dadosReserva['data_reserva']).where('turno', isEqualTo: dadosReserva['turno']).get();
        if (filaSnap.docs.isNotEmpty) {
          String dataFormatadaBR = dadosReserva['data_reserva']; try { dataFormatadaBR = DateFormat('dd/MM/yyyy').format(DateTime.parse(dataFormatadaBR)); } catch (_) {}
          for (var f in filaSnap.docs) {
            await FirebaseFirestore.instance.collection('notificacoes').add({'sindico_vinculado': widget.userData['sindico_vinculado'], 'para': (f.data()['email'] ?? '').toString().toLowerCase().trim(), 'nome_destino': 'Bloco ${f.data()['bloco']} AP ${f.data()['ap']} - ${f.data()['morador']}', 'titulo': '⚠️ ÁREA COMUM LIBERADA!', 'mensagem': 'A reserva de ${dadosReserva['nome_area']} para o dia $dataFormatadaBR (${dadosReserva['turno']}) foi cancelada. Acesse o app rápido para alugar (O primeiro a clicar, ganha)!', 'data': FieldValue.serverTimestamp(), 'remetente': 'Sistema de Reservas', 'tipo_acao': 'acao_avisos'});
            f.reference.delete();
          }
        }
        if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reserva Cancelada!"))); }
      }, child: const Text("SIM, CANCELAR", style: TextStyle(color: Colors.white)))]);
    });
  }

  void _checarInadimplenciaEProsseguir(Map<String, dynamic> areaData, String idArea) async {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      if ((await FirebaseFirestore.instance.collection('usuarios').doc(widget.userData['sindico_vinculado']).get()).data()?['bloquear_inadimplentes'] ?? false) {
        final faturasSnap = await FirebaseFirestore.instance.collection('faturas_moradores').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('email_morador', isEqualTo: widget.userData['email']).where('status', whereIn: ['PENDING', 'OVERDUE']).get();
        bool estaDevendo = false; final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        for(var fatura in faturasSnap.docs) if (DateTime.parse(fatura.data()['vencimento']).isBefore(hoje)) { estaDevendo = true; break; }
        if (estaDevendo) {
          if (!mounted) return; Navigator.pop(context);
          showDialog(context: context, builder: (c) => AlertDialog(title: const Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 10), Text("Ação Bloqueada")]), content: const Text("Consta uma pendência financeira em sua unidade. Por favor, acesse a aba 'Faturas' para regularizar a situação e liberar as reservas."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("FECHAR")), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), icon: const Icon(Icons.request_quote), label: const Text("VER FATURAS"), onPressed: () { Navigator.pop(c); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TelaMorador(userData: widget.userData, abaInicial: 5))); })]));
          return;
        }
      }
      if (!mounted) return; Navigator.pop(context); _tentarReservar(areaData, idArea);
    } catch (e) { if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro ao verificar status: $e"), backgroundColor: Colors.red)); } }
  }

  void _tentarReservar(Map<String, dynamic> areaData, String idArea) async {
    final primeiraDataPermitida = DateTime.now().add(Duration(days: int.tryParse(areaData['dias_antecedencia']?.toString() ?? '30') ?? 30)), turnosList = (areaData['turnos'] as List?) ?? [];
    DateTime dataSelecionada = primeiraDataPermitida; String turnoSelecionado = turnosList.isNotEmpty ? turnosList.first.toString() : '';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: FittedBox(fit: BoxFit.scaleDown, child: Text("Reservar ${areaData['nome']}")),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children:[const Text("Escolha a data:"), const SizedBox(height: 5), InkWell(onTap: () async { final picked = await showDatePicker(context: context, initialDate: dataSelecionada, firstDate: primeiraDataPermitida, lastDate: primeiraDataPermitida.add(const Duration(days: 365))); if (picked != null) setStateSB(() => dataSelecionada = picked); }, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: colorScheme.primary), borderRadius: BorderRadius.circular(5)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children:[Text(DateFormat('dd/MM/yyyy').format(dataSelecionada), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Icon(Icons.calendar_month, color: colorScheme.primary)]))), const SizedBox(height: 20), const Text("Escolha o Turno:"), DropdownButton<String>(isExpanded: true, value: turnoSelecionado.isEmpty ? null : turnoSelecionado, items: turnosList.map((t) => DropdownMenuItem(value: t.toString(), child: Text(t.toString()))).toList(), onChanged: (v) => setStateSB(() => turnoSelecionado = v!))]),
        actions:[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), LogicNeonButton(corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: () async {
          if (turnoSelecionado.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selecione um turno válido!"))); return; }
          final dataFormatada = DateFormat('yyyy-MM-dd').format(dataSelecionada), snap = await FirebaseFirestore.instance.collection('reservas').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('id_area', isEqualTo: idArea).where('data_reserva', isEqualTo: dataFormatada).where('turno', isEqualTo: turnoSelecionado).where('status', isEqualTo: 'confirmada').get();
          if (!mounted) return; Navigator.pop(ctx);
          if (snap.docs.isNotEmpty) _mostrarAvisoOcupado(areaData, idArea, dataFormatada, turnoSelecionado); else _mostrarTermosReserva(areaData, idArea, dataFormatada, turnoSelecionado);
        }, child: const Text("PROSSEGUIR", style: TextStyle(color: Colors.white)))]
      );
    }));
  }

  void _mostrarAvisoOcupado(Map<String, dynamic> areaData, String idArea, String dataFormatada, String turno) {
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: Row(children:[Icon(Icons.warning, color: colorScheme.secondary), const SizedBox(width: 10), const Flexible(child: Text("Área Indisponível"))]), content: Text("O espaço ${areaData['nome']} já está reservado no dia $dataFormatada ($turno). Deseja entrar na fila de espera?\n\nSe o morador cancelar, você será notificado!"), actions:[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("FECHAR")), LogicNeonButton(corBase: colorScheme.secondary, corBrilho: colorScheme.secondary, onPressed: () async { await FirebaseFirestore.instance.collection('fila_espera').add({'sindico_vinculado': widget.userData['sindico_vinculado'], 'id_area': idArea, 'nome_area': areaData['nome'], 'data_reserva': dataFormatada, 'turno': turno, 'morador': widget.userData['nome'], 'bloco': widget.userData['bloco'], 'ap': widget.userData['ap'], 'email': widget.userData['email'], 'criado_em': FieldValue.serverTimestamp()}); if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Você entrou na Fila de Espera! Fique de olho nos Avisos."))); } }, child: const FittedBox(fit: BoxFit.scaleDown, child: Text("ENTRAR NA FILA", style: TextStyle(color: Colors.white))))]);
    });
  }

  void _mostrarTermosReserva(Map<String, dynamic> areaData, String idArea, String dataFormatada, String turno) {
    bool aceitou = false; final valorTaxa = (areaData['valor_taxa'] ?? 0.0).toDouble();
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: FittedBox(fit: BoxFit.scaleDown, child: Text("Termos de Uso - ${areaData['nome']}")), content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children:[if (valorTaxa > 0) Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.withValues(alpha:0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange)), child: Row(children: [const Icon(Icons.monetization_on, color: Colors.orange), const SizedBox(width: 10), Expanded(child: Text("O valor de R\$ ${valorTaxa.toStringAsFixed(2)} será lançado na sua próxima taxa de condomínio referente a este aluguel.", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)))])), Container(padding: const EdgeInsets.all(10), height: 150, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(5)), child: SingleChildScrollView(child: Text(areaData['regras'] ?? 'Nenhuma regra informada.', style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)))), const SizedBox(height: 15), CheckboxListTile(title: const Text("Eu li e concordo com as regras e com a cobrança da taxa (se houver).", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), value: aceitou, activeColor: colorScheme.primary, onChanged: (v) => setStateSB(() => aceitou = v!), controlAffinity: ListTileControlAffinity.leading)])), actions:[TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), LogicNeonButton(corBase: aceitou ? Colors.green : Colors.grey, corBrilho: aceitou ? Colors.greenAccent : Colors.grey, onPressed: !aceitou ? () {} : () async {
        final snap = await FirebaseFirestore.instance.collection('reservas').where('id_area', isEqualTo: idArea).where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('data_reserva', isEqualTo: dataFormatada).where('turno', isEqualTo: turno).where('status', isEqualTo: 'confirmada').get();
        if (!mounted) return;
        if (snap.docs.isEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          batch.set(FirebaseFirestore.instance.collection('reservas').doc(), {'sindico_vinculado': widget.userData['sindico_vinculado'], 'id_area': idArea, 'nome_area': areaData['nome'], 'data_reserva': dataFormatada, 'turno': turno, 'morador': widget.userData['nome'], 'bloco': widget.userData['bloco'], 'ap': widget.userData['ap'], 'email': widget.userData['email'], 'status': 'confirmada', 'criado_em': FieldValue.serverTimestamp()});
          if (valorTaxa > 0) batch.set(FirebaseFirestore.instance.collection('cobrancas_extras').doc(), {'sindico_vinculado': widget.userData['sindico_vinculado'], 'email_morador': widget.userData['email'], 'nome_morador': widget.userData['nome'], 'bloco': widget.userData['bloco'], 'ap': widget.userData['ap'], 'tipo': 'reserva', 'titulo': 'Aluguel: ${areaData['nome']}', 'descricao': 'Reserva para o dia $dataFormatada no turno $turno.', 'valor': valorTaxa, 'status': 'pendente_faturamento', 'data_criacao': FieldValue.serverTimestamp()});
          await batch.commit();
          String dataBR = dataFormatada; try { dataBR = DateFormat('dd/MM/yyyy').format(DateTime.parse(dataFormatada)); } catch (_) {}
          await FirebaseFirestore.instance.collection('notificacoes').add({'sindico_vinculado': widget.userData['sindico_vinculado'], 'para': widget.userData['email'].toString().toLowerCase().trim(), 'nome_destino': 'Bloco ${widget.userData['bloco']} AP ${widget.userData['ap']} - ${widget.userData['nome']}', 'titulo': '✅ RESERVA CONFIRMADA!', 'mensagem': 'Sua reserva para ${areaData['nome']} no dia $dataBR ($turno) foi efetivada com sucesso.', 'data': FieldValue.serverTimestamp(), 'remetente': 'Sistema de Reservas', 'tipo_acao': 'acao_avisos'});
          if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reserva Confirmada com Sucesso!"), backgroundColor: Colors.green)); }
        } else { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Ops! Alguém alugou antes de você terminar de ler."), backgroundColor: colorScheme.error)); }
      }, child: const FittedBox(fit: BoxFit.scaleDown, child: Text("CONFIRMAR RESERVA", style: TextStyle(color: Colors.white))))]);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(length: 2, child: Column(children:[TabBar(labelColor: colorScheme.primary, unselectedLabelColor: colorScheme.onSurfaceVariant, indicatorColor: colorScheme.primary, tabs: const[Tab(text: "Nova Reserva"), Tab(text: "Meu Histórico")]), Expanded(child: TabBarView(children:[StreamBuilder<QuerySnapshot>(stream: _areasStream, builder: (context, snap) {
      if (snap.hasError) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.wifi_off, size: 50, color: colorScheme.error), const SizedBox(height: 15), Text("Sessão expirada ou erro de conexão.", style: TextStyle(color: colorScheme.onSurfaceVariant)), const SizedBox(height: 10), ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("Recarregar"), onPressed: _reconectarBancoDeDados)]));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhuma área disponível para aluguel."));
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) {
        final doc = snap.data!.docs[i], data = doc.data() as Map<String, dynamic>;
        return Card(elevation: 3, margin: const EdgeInsets.only(bottom: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children:[Container(height: 100, decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(15)), child: Icon(Icons.deck, size: 60, color: colorScheme.primary)), Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[FittedBox(fit: BoxFit.scaleDown, child: Text(data['nome'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))), const SizedBox(height: 5), FittedBox(fit: BoxFit.scaleDown, child: Text("Requer no mínimo ${data['dias_antecedencia']} dias de antecedência para reserva.", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13))), const SizedBox(height: 15), LogicNeonButton(fullWidth: true, corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: () => _checarInadimplenciaEProsseguir(data, doc.id), child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.calendar_month, color: Colors.white, size: 18), SizedBox(width: 8), Text("VER DISPONIBILIDADE", style: TextStyle(color: Colors.white))]))]))]));
      });
    }), Column(children:[Padding(padding: const EdgeInsets.all(16), child: Row(children:[FittedBox(fit: BoxFit.scaleDown, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: _dataFiltroInicio != null ? colorScheme.primary : colorScheme.surfaceContainerHighest, foregroundColor: _dataFiltroInicio != null ? colorScheme.onPrimary : colorScheme.onSurfaceVariant), icon: const Icon(Icons.calendar_month), label: Text(_dataFiltroInicio != null ? "${DateFormat('dd/MM').format(_dataFiltroInicio!)} - ${DateFormat('dd/MM').format(_dataFiltroFim!)}" : "Filtrar por Data"), onPressed: () => _selecionarDataFiltro(context))), if (_dataFiltroInicio != null) IconButton(icon: Icon(Icons.clear, color: colorScheme.error), onPressed: () => setState(() { _dataFiltroInicio = null; _dataFiltroFim = null; }))])), Expanded(child: StreamBuilder<QuerySnapshot>(stream: _minhasReservasStream, builder: (context, snap) {
      if (snap.hasError) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.wifi_off, size: 50, color: colorScheme.error), const SizedBox(height: 15), Text("Sessão expirada ou erro de conexão.", style: TextStyle(color: colorScheme.onSurfaceVariant)), const SizedBox(height: 10), ElevatedButton.icon(icon: const Icon(Icons.refresh), label: const Text("Recarregar"), onPressed: _reconectarBancoDeDados)]));
      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
      final docs = snap.data!.docs.where((d) { final data = d.data() as Map<String, dynamic>; if (_dataFiltroInicio != null && data['data_reserva'] != null) { try { final dt = DateTime.parse(data['data_reserva']); if (dt.isBefore(_dataFiltroInicio!) || dt.isAfter(_dataFiltroFim!)) return false; } catch (_) { return false; } } return true; }).toList()..sort((a, b) => ((b.data() as Map)['data_reserva'] ?? '').compareTo((a.data() as Map)['data_reserva'] ?? ''));
      if (docs.isEmpty) return Center(child: Text("Você ainda não tem reservas.", style: TextStyle(color: colorScheme.onSurfaceVariant)));
      return ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length, itemBuilder: (ctx, i) {
        final doc = docs[i], data = doc.data() as Map<String, dynamic>, isCancelada = data['status'] == 'cancelada'; String dataExibicao = data['data_reserva'] ?? ''; DateTime? dataReservaDt; bool isPassado = false;
        try { dataReservaDt = DateTime.parse(dataExibicao); dataExibicao = DateFormat('dd/MM/yyyy').format(dataReservaDt); isPassado = dataReservaDt.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)); } catch (_) {}
        return Card(child: ListTile(leading: Icon(isCancelada ? Icons.cancel : Icons.check_circle, color: isCancelada ? colorScheme.error : Colors.green, size: 40), title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("${data['nome_area']}", style: const TextStyle(fontWeight: FontWeight.bold))), subtitle: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Data: $dataExibicao\nTurno: ${data['turno']}")), trailing: isCancelada ? FittedBox(fit: BoxFit.scaleDown, child: Text("CANCELADA", style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold))) : (isPassado ? const FittedBox(fit: BoxFit.scaleDown, child: Text("CONCLUÍDA", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))) : FittedBox(fit: BoxFit.scaleDown, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.errorContainer, foregroundColor: colorScheme.onErrorContainer), onPressed: () => _cancelarReserva(doc.reference, data), child: const Text("CANCELAR"))))));
      });
    }))])]))]));
  }
}

// [FIM DO BLOCO - DIGITE "CONTINUE" PARA GERAR A PRÓXIMA PARTE]
// ============================================================================
// Aceite LGPD e Termos de Uso
// ============================================================================
void mostrarTermosDeUso(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children:[Icon(Icons.gavel, color: colorScheme.primary), const SizedBox(width: 10), const Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Termos de Uso e Privacidade")))]),
      content: SizedBox(
        width: 600, height: MediaQuery.of(context).size.height * 0.7,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text("Última atualização: [19/04/2026]", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)), SizedBox(height: 15),
            Text("Bem-vindo ao Logic Home. Este documento contém os Termos de Uso e a Política de Privacidade aplicáveis ao uso do sistema Logic Home (\"Plataforma\", \"Sistema\" ou \"Aplicativo\"), que engloba aplicativos móveis, painéis web e aplicações desktop.\n\nO Logic Home é um software no modelo SaaS (Software as a Service) desenvolvido por [Nome da sua Empresa ou seu Nome], CNPJ/CPF [Seu CNPJ/CPF], com sede em [Sua Cidade/Estado].\n\nAo criar uma conta, fazer login ou utilizar qualquer funcionalidade do Logic Home, você declara que leu, compreendeu e concorda integralmente com estes Termos. Caso não concorde, por favor, não utilize a Plataforma."),
            SizedBox(height: 20), Text("PARTE I: TERMOS DE USO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Divider(),
            Text("1. Natureza do Serviço", style: TextStyle(fontWeight: FontWeight.bold)), Text("O Logic Home é uma plataforma tecnológica de gestão condominial, controle de acesso, interfonia de vídeo e gerenciamento de facilidades.\nImportante: O Logic Home fornece apenas a tecnologia. As regras de convivência, horários e autorizações são definidas exclusivamente pela Administração do Condomínio (Síndico)."), SizedBox(height: 10),
            Text("2. Perfis de Usuário e Responsabilidades", style: TextStyle(fontWeight: FontWeight.bold)), Text("• Morador: Responsável por manter seus dados atualizados. Ao gerar Convites VIP ou liberar acessos via aplicativo, o morador assume total responsabilidade civil e criminal sobre as pessoas que autoriza a entrar. O uso do PIN para retirada de encomendas equivale a uma assinatura digital.\n• Síndico: Age como o representante legal do Condomínio. É responsável por aprovar moradores e configurar regras.\n• Porteiro / Staff: Responsável por operar a portaria de forma ética e profissional.\n• Visitante: Usuários temporários para fins exclusivos de liberação pontual."), SizedBox(height: 10),
            Text("3. Uso Aceitável", style: TextStyle(fontWeight: FontWeight.bold)), Text("Você concorda em não:\n- Compartilhar sua senha ou código PIN pessoal com terceiros.\n- Cadastrar biometria facial de terceiros sem consentimento.\n- Tentar burlar, hackear ou testar a vulnerabilidade da Plataforma ou equipamentos IoT.\n- Usar a Plataforma para atividades ilícitas."), SizedBox(height: 10),
            Text("4. Disponibilidade do Sistema", style: TextStyle(fontWeight: FontWeight.bold)), Text("O Logic Home se esforça para manter a plataforma online 24/7. No entanto, por depender de internet, energia e serviços em nuvem, não garantimos disponibilidade ininterrupta."),
            SizedBox(height: 20), Text("PARTE II: POLÍTICA DE PRIVACIDADE E LGPD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Divider(),
            Text("1. O Papel do Logic Home (Operador vs. Controlador)", style: TextStyle(fontWeight: FontWeight.bold)), Text("Para fins da LGPD, o Condomínio (Síndico) é o Controlador dos dados. O Logic Home atua exclusivamente como Operador, processando as informações estritamente para o funcionamento do sistema."), SizedBox(height: 10),
            Text("2. Quais dados coletamos e por quê?", style: TextStyle(fontWeight: FontWeight.bold)), Text("• Dados Cadastrais: Nome, e-mail, telefone, CPF/RG, bloco e apartamento.\n• Dados Biométricos: Fotos do rosto para controle de acesso facial.\n• Dados de Documentos (OCR): Extração automatizada para auditoria.\n• Veículos: Placa, modelo e cor.\n• Registros de Acesso (Logs): Auditoria de segurança.\n• Imagens de Câmeras: O Logic Home não grava nem armazena filmagens, atuando apenas como túnel de visualização ao vivo."), SizedBox(height: 10),
            Text("3. Compartilhamento de Dados", style: TextStyle(fontWeight: FontWeight.bold)), Text("Seus dados NÃO são vendidos ou compartilhados para publicidade. São compartilhados estritamente com a Administração do seu Condomínio e Servidores de infraestrutura em nuvem (ex: Google Cloud)."), SizedBox(height: 10),
            Text("4. Armazenamento e Segurança da Informação", style: TextStyle(fontWeight: FontWeight.bold)), Text("Utilizamos criptografia avançada (AES), comunicação segura e controle de sessão contra múltiplos acessos e prints de tela em áreas sensíveis."), SizedBox(height: 10),
            Text("5. Retenção e Exclusão de Dados", style: TextStyle(fontWeight: FontWeight.bold)), Text("Como o Condomínio é o Controlador, solicitações de exclusão devem ser direcionadas ao Síndico. O condomínio possui o direito legal de reter logs de acesso pelo tempo estipulado em lei."), SizedBox(height: 10),
            Text("6. Direitos do Titular", style: TextStyle(fontWeight: FontWeight.bold)), Text("Você pode acessar, corrigir dados (sujeito à aprovação) e revogar permissões do app via seu smartphone."),
            SizedBox(height: 20), Text("PARTE III: DISPOSIÇÕES GERAIS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Divider(),
            Text("Todo o código-fonte, design e arquitetura pertencem ao desenvolvedor. É proibida a cópia ou engenharia reversa.\n\nContato e Dúvidas:\n📧 [Seu e-mail de suporte]\n\nAo utilizar o Logic Home, você concorda em fazer parte de um ambiente condominial mais seguro, tecnológico e transparente."),
          ]),
        ),
      ),
      actions:[LogicNeonButton(corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: () => Navigator.pop(ctx), child: const Text("CONCLUIR LEITURA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]
    ),
  );
}

// ============================================================================
// Visualizador 4G Morador/Síndico (ARQUITETURA DIAMANTE - JWT ON-DEMAND)
// ============================================================================
class PlayerNuvem extends StatefulWidget {
  final String nomeCamera, cameraId, sindicoVinculado;
  final VoidCallback? onEdit, onDelete;
  const PlayerNuvem({super.key, required this.nomeCamera, required this.cameraId, required this.sindicoVinculado, this.onEdit, this.onDelete});
  @override
  State<PlayerNuvem> createState() => _PlayerNuvemState();
}

class _PlayerNuvemState extends State<PlayerNuvem> with TickerProviderStateMixin {
  Player? _player; VideoController? _videoController;
  String _status = 'iniciando'; bool _isDisposed = false;
  Timer? _watchdogTimer, _timeoutSetupTimer; Duration _ultimaPosicao = Duration.zero;
  late AnimationController _piscaController;
  int _tentativasReconexao = 0;
  static const int MAX_TENTATIVAS = 3;

  @override
  void initState() {
    super.initState();
    _piscaController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _iniciarPedidoComJWT();
  }

  Future<void> _iniciarPedidoComJWT() async {
    if (_isDisposed) return;
    _timeoutSetupTimer?.cancel();
    _timeoutSetupTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && _status != 'ativo' && !_isDisposed) { setState(() => _status = 'erro'); _agendarReconexaoNuvem("Timeout Setup"); }
    });
    
    try {
      final docSindico = await FirebaseFirestore.instance.collection('usuarios').doc(widget.sindicoVinculado).get();
      if (docSindico.data()?['tunel_online'] != true) { if (mounted) setState(() => _status = 'offline'); _agendarReconexaoNuvem("Offline"); return; }
      String urlBaseCloudflare = docSindico.data()?['url_tunel_video'] ?? '';
      if (urlBaseCloudflare.isEmpty) { if (mounted) setState(() => _status = 'erro'); _agendarReconexaoNuvem("URL Vazia"); return; }
      if (urlBaseCloudflare.endsWith('/')) urlBaseCloudflare = urlBaseCloudflare.substring(0, urlBaseCloudflare.length - 1);
      if (mounted) setState(() => _status = 'iniciando');

      final response = await FirebaseFunctions.instance.httpsCallable('solicitarAcessoVideo').call({'sindico_alvo': widget.sindicoVinculado, 'camera_id': widget.cameraId});
      if (_isDisposed) return;

      if (response.data['sucesso'] == true) {
        if (mounted) setState(() { _status = 'autenticando'; _tentativasReconexao = 0; });
        final ingressoJwt = response.data['jwt'] ?? '', triggerUrl = '$urlBaseCloudflare/${widget.cameraId}/?token=$ingressoJwt', hlsUrl = '$urlBaseCloudflare/${widget.cameraId}/index.m3u8?token=$ingressoJwt';
        http.get(Uri.parse(triggerUrl)).catchError((_) => http.Response('', 500));
        
        if (await _aguardarStreamPronta(hlsUrl)) {
          if (_isDisposed) return;
          if (mounted) setState(() => _status = 'acordando_camera');
          _inicializarVideoNuvem("$hlsUrl&nocache=${DateTime.now().millisecondsSinceEpoch}");
        } else {
          if (mounted) setState(() => _status = 'erro'); _agendarReconexaoNuvem("Demorou muito para acordar");
        }
      } else if (mounted) setState(() => _status = 'negado');
    } catch (_) { if (mounted) setState(() => _status = 'erro'); _agendarReconexaoNuvem("Erro de nuvem"); }
  }

  Future<bool> _aguardarStreamPronta(String urlBase) async {
    for (int tentativas = 0; tentativas < 15 && !_isDisposed; tentativas++) {
      try { if ((await http.get(Uri.parse("$urlBase&nocache=${DateTime.now().millisecondsSinceEpoch}")).timeout(const Duration(seconds: 3))).statusCode == 200) return true; } catch (_) {}
      await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  void _inicializarVideoNuvem(String hlsUrl) {
    if (_isDisposed) return;
    _player = Player(); _videoController = VideoController(_player!);
    _player!.stream.error.listen((_) { if (mounted && !_isDisposed) { setState(() => _status = 'reconectando'); _agendarReconexaoNuvem("Erro de Reprodução"); } });
    _player!.stream.playing.listen((isPlaying) { if (mounted && isPlaying && !_isDisposed) { _timeoutSetupTimer?.cancel(); setState(() => _status = 'ativo'); _iniciarWatchdogAntiCongelamento(); } });
    _player!.open(Media(hlsUrl), play: true);
  }

  void _iniciarWatchdogAntiCongelamento() {
    _watchdogTimer?.cancel(); _ultimaPosicao = Duration.zero;
    _watchdogTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (_isDisposed || _player == null) { timer.cancel(); return; }
      final pos = _player!.state.position;
      if (pos == _ultimaPosicao && pos > Duration.zero) { timer.cancel(); setState(() => _status = 'reconectando'); _agendarReconexaoNuvem("Congelou"); } else _ultimaPosicao = pos;
    });
  }

  void _agendarReconexaoNuvem(String motivo) {
    if (_isDisposed) return; _timeoutSetupTimer?.cancel(); _watchdogTimer?.cancel();
    _player?.dispose(); _player = null; _videoController = null;
    _tentativasReconexao++;
    if (_tentativasReconexao > MAX_TENTATIVAS) {
      if (mounted) setState(() => _status = 'falha_definitiva');
      return;
    }
    Future.delayed(const Duration(seconds: 5), () { if (mounted && !_isDisposed) _iniciarPedidoComJWT(); });
  }

  @override
  void dispose() { _isDisposed = true; _timeoutSetupTimer?.cancel(); _watchdogTimer?.cancel(); _piscaController.dispose(); _player?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.black, clipBehavior: Clip.antiAlias, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: AspectRatio(aspectRatio: 16 / 9, child: Stack(fit: StackFit.expand, children:[
        if (_status == 'ativo' && _videoController != null) Video(controller: _videoController!, controls: NoVideoControls),
        if (['iniciando', 'autenticando', 'acordando_camera', 'reconectando'].contains(_status)) Column(mainAxisAlignment: MainAxisAlignment.center, children:[const CircularProgressIndicator(color: Colors.blue), const SizedBox(height: 15), FadeTransition(opacity: _piscaController, child: FittedBox(fit: BoxFit.scaleDown, child: Text(['iniciando', 'reconectando'].contains(_status) ? "Conectando ao servidor..." : (_status == 'autenticando' ? "Criptografando..." : "Conectando..."), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)))), const SizedBox(height: 8), const FittedBox(fit: BoxFit.scaleDown, child: Text("Isso leva no máximo 8 segundos.", style: TextStyle(color: Colors.white54, fontSize: 11)))]),
        if (_status == 'falha_definitiva') Column(mainAxisAlignment: MainAxisAlignment.center, children:[const Icon(Icons.videocam_off, color: Colors.red, size: 40), const SizedBox(height: 10), const FittedBox(fit: BoxFit.scaleDown, child: Text("Câmera Offline", style: TextStyle(color: Colors.white, fontSize: 12))), const SizedBox(height: 10), TextButton.icon(icon: const Icon(Icons.refresh, color: Colors.blue, size: 16), label: const Text("Tentar Novamente", style: TextStyle(color: Colors.blue)), onPressed: () { setState(() { _tentativasReconexao = 0; _status = 'iniciando'; }); _iniciarPedidoComJWT(); })]),
        if (['offline', 'erro'].contains(_status)) Column(mainAxisAlignment: MainAxisAlignment.center, children:[const Icon(Icons.cloud_off, color: Colors.orange, size: 40), const SizedBox(height: 10), FittedBox(fit: BoxFit.scaleDown, child: Text(_status == 'offline' ? "Portaria Offline. Tentando novamente..." : "Falha na imagem. Reconectando...", style: const TextStyle(color: Colors.white, fontSize: 12)))]),
        if (_status == 'negado') const Column(mainAxisAlignment: MainAxisAlignment.center, children:[Icon(Icons.security, color: Colors.orange, size: 40), SizedBox(height: 10), FittedBox(fit: BoxFit.scaleDown, child: Text("Acesso Negado (Sem permissão).", style: TextStyle(color: Colors.white, fontSize: 12)))]),
        if (widget.onEdit != null || widget.onDelete != null) Positioned(top: 0, right: 0, child: Container(decoration: BoxDecoration(color: Colors.black.withValues(alpha:0.6), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(10))), child: Row(mainAxisSize: MainAxisSize.min, children:[if (widget.onEdit != null) IconButton(icon: const Icon(Icons.settings, color: Colors.blue, size: 18), tooltip: "Configurar Câmera", onPressed: widget.onEdit, padding: const EdgeInsets.all(8), constraints: const BoxConstraints()), if (widget.onDelete != null) IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), tooltip: "Excluir Câmera", onPressed: widget.onDelete, padding: const EdgeInsets.all(8), constraints: const BoxConstraints())]))),
        Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors:[Colors.black87, Colors.transparent])), child: Row(children:[Icon(Icons.fiber_manual_record, color: _status == 'ativo' ? Colors.red : Colors.grey, size: 12), const SizedBox(width: 8), Expanded(child: Text(widget.nomeCamera, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))), const Icon(Icons.cloud_sync, color: Colors.blue, size: 16), const SizedBox(width: 5), const FittedBox(fit: BoxFit.scaleDown, child: Text("Via Nuvem 4G", style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)))])))
      ])),
    );
  }
}

// ============================================================================
// Decide automaticamente se usa Wi-Fi Local ou Túnel 4G Cloudflare
// ============================================================================
class SmartCameraPlayer extends StatefulWidget {
  final String nomeCamera, cameraId, sindicoVinculado, ipLocal, portaRtsp, usuario, senha, canal;
  final VoidCallback? onEdit, onDelete;
  const SmartCameraPlayer({super.key, required this.nomeCamera, required this.cameraId, required this.sindicoVinculado, required this.ipLocal, required this.portaRtsp, required this.usuario, required this.senha, required this.canal, this.onEdit, this.onDelete});
  @override
  State<SmartCameraPlayer> createState() => _SmartCameraPlayerState();
}

class _SmartCameraPlayerState extends State<SmartCameraPlayer> {
  bool _verificandoRede = true, _redeLocalAcessivel = false;

  @override
  void initState() { super.initState(); _testarConexaoLocal(); }

  Future<void> _testarConexaoLocal() async {
    if (kIsWeb || widget.ipLocal.isEmpty) { if (mounted) setState(() { _verificandoRede = false; _redeLocalAcessivel = false; }); return; }
    try {
      final socket = await Socket.connect(widget.ipLocal, int.tryParse(widget.portaRtsp) ?? 554, timeout: const Duration(milliseconds: 1500));
      socket.destroy(); if (mounted) setState(() { _redeLocalAcessivel = true; _verificandoRede = false; });
    } catch (_) { if (mounted) setState(() { _redeLocalAcessivel = false; _verificandoRede = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    if (_verificandoRede) return Card(color: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: const AspectRatio(aspectRatio: 16 / 9, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.blue), SizedBox(height: 10), Text("Analisando a rede (Wi-Fi/4G)...", style: TextStyle(color: Colors.white70, fontSize: 10))]))));
    return _redeLocalAcessivel ? PlayerIntelbras(nomeCamera: widget.nomeCamera, ip: widget.ipLocal, usuario: widget.usuario, senha: widget.senha, canal: widget.canal, portaRtsp: widget.portaRtsp, altaQualidade: false, onEdit: widget.onEdit, onDelete: widget.onDelete) : PlayerNuvem(nomeCamera: widget.nomeCamera, cameraId: widget.cameraId, sindicoVinculado: widget.sindicoVinculado, onEdit: widget.onEdit, onDelete: widget.onDelete);
  }
}

// ============================================================================
// DESPESAS: TELA EXCLUSIVA DO SÍNDICO LOCAL
// ============================================================================
class TelaDespesasSindico extends StatefulWidget {
  final String emailSindico;
  const TelaDespesasSindico({super.key, required this.emailSindico});
  @override
  State<TelaDespesasSindico> createState() => _TelaDespesasSindicoState();
}

class _TelaDespesasSindicoState extends State<TelaDespesasSindico> {
  DateTime _mesFiltro = DateTime.now();

  void _modalLancarDespesa() {
    String titulo = "", descricao = "", valorStr = ""; DateTime dataDaDespesa = DateTime.now(); bool salvando = false;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const Row(children: [Icon(Icons.money_off, color: Colors.red), SizedBox(width: 10), Text("Lançar Despesa / Gasto")]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("Lembre-se de enviar os comprovantes (Notas Fiscais/Recibos) originais em anexo para o e-mail da Administradora para a prestação de contas legal.", style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 15),
          TextField(onChanged: (v) => titulo = v, decoration: const InputDecoration(labelText: "Título (Ex: Conta de Água)", border: OutlineInputBorder())), const SizedBox(height: 10),
          TextField(onChanged: (v) => descricao = v, maxLines: 2, decoration: const InputDecoration(labelText: "Descrição/Referência", border: OutlineInputBorder())), const SizedBox(height: 10),
          TextField(onChanged: (v) => valorStr = v.replaceAll(',', '.'), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Valor (R\$)", prefixText: "R\$ ", border: OutlineInputBorder())), const SizedBox(height: 15),
          InkWell(onTap: () async { final picked = await showDatePicker(context: context, initialDate: dataDaDespesa, firstDate: DateTime(2020), lastDate: DateTime.now()); if (picked != null) setStateSB(() => dataDaDespesa = picked); }, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Data do Pagamento: ${DateFormat('dd/MM/yyyy').format(dataDaDespesa)}", style: const TextStyle(fontWeight: FontWeight.bold)), const Icon(Icons.calendar_month)])))
        ])),
        actions: [
          if (!salvando) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError), onPressed: salvando ? null : () async {
            if (titulo.isEmpty || valorStr.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha o título e o valor!"))); return; }
            setStateSB(() => salvando = true);
            try {
              await FirebaseFirestore.instance.collection('despesas_condominio').add({'sindico_vinculado': widget.emailSindico, 'titulo': titulo, 'descricao': descricao, 'valor': double.parse(valorStr), 'data_pagamento': Timestamp.fromDate(dataDaDespesa), 'data_registro': FieldValue.serverTimestamp(), 'lancado_por': operadorLogado});
              if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Despesa registrada com sucesso!"), backgroundColor: Colors.green)); }
            } catch (e) { 
              if (mounted) {
                setStateSB(() => salvando = false); 
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red)); 
              }
            }
          }, child: salvando ? const CircularProgressIndicator(color: Colors.white) : const Text("REGISTRAR DESPESA"))
        ]
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme, mesAnoFormat = DateFormat('MM/yyyy').format(_mesFiltro);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _modalLancarDespesa, backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError, icon: const Icon(Icons.add), label: const Text("Lançar Gasto", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [Icon(Icons.money_off, size: 40, color: colorScheme.error), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Despesas do Condomínio", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Text("Lance os gastos do mês para a Administradora realizar o fechamento do Balancete.", style: TextStyle(color: colorScheme.onSurfaceVariant))]))])),
        Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20), color: colorScheme.surfaceContainerHighest, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () => setState(() => _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month - 1, 1))), Text("Mês Referência: $mesAnoFormat", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 18), onPressed: () => setState(() => _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month + 1, 1)))])),
        Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('despesas_condominio').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots(), builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs.where((d) { final data = d.data() as Map<String, dynamic>; if (data['data_pagamento'] != null) { final dt = (data['data_pagamento'] as Timestamp).toDate(); return dt.month == _mesFiltro.month && dt.year == _mesFiltro.year; } return false; }).toList()..sort((a, b) => (b['data_pagamento'] ?? Timestamp.now()).compareTo(a['data_pagamento'] ?? Timestamp.now()));
          if (docs.isEmpty) return const Center(child: Text("Nenhuma despesa lançada neste mês.", style: TextStyle(color: Colors.grey)));
          final totalDespesas = docs.fold(0.0, (somaAt, doc) => somaAt + ((doc.data() as Map)['valor'] ?? 0.0));
          return Column(children: [
            Container(width: double.infinity, padding: const EdgeInsets.all(15), color: colorScheme.error.withValues(alpha:0.1), child: Text("Total Gasto no Mês: R\$ ${totalDespesas.toStringAsFixed(2)}", textAlign: TextAlign.center, style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold, fontSize: 18))),
            Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length, itemBuilder: (c, i) { final doc = docs[i], data = doc.data() as Map<String, dynamic>, dtPagto = DateFormat('dd/MM/yyyy').format((data['data_pagamento'] as Timestamp).toDate()); return Card(elevation: 2, child: ListTile(leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.receipt, color: Colors.white)), title: Text(data['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Pago em: $dtPagto\nLançado por: ${data['lancado_por'] ?? 'Sistema'}"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("R\$ ${data['valor'].toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(width: 10), IconButton(icon: Icon(Icons.delete, color: colorScheme.error), onPressed: () => doc.reference.delete())]))); }))
          ]);
        }))
      ]),
    );
  }
}

// ============================================================================
// FINANCEIRO: GESTÃO DE COBRANÇAS DA ADMINISTRADORA
// ============================================================================
class TelaCobrancasAdmin extends StatefulWidget {
  final String emailSindico;
  const TelaCobrancasAdmin({super.key, required this.emailSindico});
  @override
  State<TelaCobrancasAdmin> createState() => _TelaCobrancasAdminState();
}

class _TelaCobrancasAdminState extends State<TelaCobrancasAdmin> {
  final _valorCtrl = TextEditingController(); DateTime? _dataVencimento; bool _processando = false;
  final Map<String, List<Map<String, dynamic>>> _faturasCachePorMes = {}, _despesasCachePorMes = {}, _multasCachePorMes = {};
  bool _carregandoFinanceiro = false; late Stream<QuerySnapshot> _tiposMultaStream;
  DateTime _mesFiltroPrestacao = DateTime.now(), _mesFiltroDashboard = DateTime.now(), _mesFiltroMultas = DateTime.now();
  String _buscaDashboard = "";

  Future<void> _carregarFinanceiroDoMes(DateTime mes) async {
    final chaveMes = "${mes.year}-${mes.month.toString().padLeft(2, '0')}", prefs = await SharedPreferences.getInstance(), cacheKey = 'fin_${widget.emailSindico}_$chaveMes', hdDados = prefs.getString(cacheKey) ?? '';
    if (hdDados.isNotEmpty) { final dec = jsonDecode(hdDados); _faturasCachePorMes[chaveMes] = List<Map<String, dynamic>>.from(dec['faturas']); _despesasCachePorMes[chaveMes] = List<Map<String, dynamic>>.from(dec['despesas']); _multasCachePorMes[chaveMes] = List<Map<String, dynamic>>.from(dec['multas']); if (mounted) setState(() {}); } else if (mounted) setState(() => _carregandoFinanceiro = true);

    try {
      DateTime inicioJanela = DateTime(mes.year, mes.month - 3, 1);
      DateTime fimJanela = DateTime(mes.year, mes.month + 3, 0);
      String strInicio = DateFormat('yyyy-MM-dd').format(inicioJanela);
      String strFim = DateFormat('yyyy-MM-dd').format(fimJanela);
      
      DateTime inicioMes = DateTime(mes.year, mes.month, 1);
      DateTime fimMes = DateTime(mes.year, mes.month + 1, 0, 23, 59, 59);

      final faturasDoMes = (await FirebaseFirestore.instance.collection('faturas_moradores').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('vencimento', isGreaterThanOrEqualTo: strInicio).where('vencimento', isLessThanOrEqualTo: strFim).get()).docs.map((doc) => doc.data()..['id'] = doc.id).where((data) {
        bool p = false;
        if (['RECEIVED', 'CONFIRMED'].contains(data['status'])) {
          if (data['data_pagamento'] != null) { final dt = data['data_pagamento'] is Timestamp ? (data['data_pagamento'] as Timestamp).toDate() : DateTime.parse(data['data_pagamento'].toString()); if (dt.year == mes.year && dt.month == mes.month) p = true; }
          else if (data['vencimento'] != null) { final dt = DateTime.parse(data['vencimento']); if (dt.year == mes.year && dt.month == mes.month) p = true; }
        } else if (data['vencimento'] != null) { final dt = DateTime.parse(data['vencimento']); if (dt.year == mes.year && dt.month == mes.month) p = true; }
        return p;
      }).map((d) => d.map((k, v) => MapEntry(k, v is Timestamp ? v.toDate().toIso8601String() : v))).toList();
      
      final despesasDoMes = (await FirebaseFirestore.instance.collection('despesas_condominio').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('data_pagamento', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes)).where('data_pagamento', isLessThanOrEqualTo: Timestamp.fromDate(fimMes)).get()).docs.map((d) => d.data()..['id'] = d.id).map((d) => d.map((k, v) => MapEntry(k, v is Timestamp ? v.toDate().toIso8601String() : v))).toList();
      
      final multasDoMes = (await FirebaseFirestore.instance.collection('cobrancas_extras').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('data_criacao', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes)).where('data_criacao', isLessThanOrEqualTo: Timestamp.fromDate(fimMes)).get()).docs.map((d) => d.data()..['id'] = d.id).map((d) => d.map((k, v) => MapEntry(k, v is Timestamp ? v.toDate().toIso8601String() : v))).toList();

      _faturasCachePorMes[chaveMes] = faturasDoMes; _despesasCachePorMes[chaveMes] = despesasDoMes; _multasCachePorMes[chaveMes] = multasDoMes;
      await prefs.setString(cacheKey, jsonEncode({'faturas': faturasDoMes, 'despesas': despesasDoMes, 'multas': multasDoMes}));
      if (mounted) setState(() => _carregandoFinanceiro = false);
    } catch (e) { if (mounted) setState(() => _carregandoFinanceiro = false); debugPrint("❌ ERRO NO FINANCEIRO: $e"); }
  }

  void _modalCriarContaBancaria() {
    String nomeLegal = "", cpfCnpj = "", nascimento = "", tipoEmpresa = "MEI", telefone = "", cep = "", endereco = "", numero = "", complemento = "", bairro = "", faturamento = ""; bool criando = false, aceitouAvisoLegal = false;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const Row(children: [Icon(Icons.account_balance, color: Colors.blue), SizedBox(width: 10), Text("Abrir Conta Bancária")]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withValues(alpha:0.1), border: Border.all(color: Colors.red), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Expanded(child: Text("AVISO LEGAL IMPORTANTE", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))]), const SizedBox(height: 8), const Text("1. A conta deve ser criada com os DADOS REAIS da pessoa ou empresa que receberá o dinheiro.\n2. Por normas do Banco Central, a conta no Asaas SÓ SERÁ LIBERADA APÓS ENVIO DE FOTO DO DOCUMENTO E SELFIE no e-mail cadastrado.\n3. Há uma tarifa cobrada pelo banco de R\$ 1,00 a R\$ 2,00 por boleto compensado.\n4. A responsabilidade legal e fiscal pelos fundos transacionados é exclusiva do titular da conta.", style: TextStyle(fontSize: 12, color: Colors.black87)), const SizedBox(height: 10), CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, activeColor: Colors.red, title: const Text("Li e assumo a responsabilidade.", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)), value: aceitouAvisoLegal, onChanged: (v) => setStateSB(() => aceitouAvisoLegal = v!))])), const SizedBox(height: 15),
          const Text("Para emitir boletos, preencha os dados com extrema atenção.", style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 15),
          TextField(onChanged: (v) => nomeLegal = v, decoration: const InputDecoration(labelText: "Nome da Empresa ou Pessoa (Como no Documento Oficial)", border: OutlineInputBorder(), helperText: "Não use abreviações ou nomes fantasias.")), const SizedBox(height: 10),
          Row(children: [Expanded(flex: 2, child: DropdownButtonFormField<String>(isExpanded: true, initialValue: tipoEmpresa, decoration: const InputDecoration(labelText: "Tipo de Registro", border: OutlineInputBorder()), items: const [DropdownMenuItem(value: "INDIVIDUAL", child: Text("Pessoa Física (CPF)")), DropdownMenuItem(value: "MEI", child: Text("Empresa MEI (CNPJ)")), DropdownMenuItem(value: "LIMITED", child: Text("Empresa LTDA (CNPJ)")), DropdownMenuItem(value: "ASSOCIATION", child: Text("Associação (CNPJ)"))], onChanged: (v) => setStateSB(() => tipoEmpresa = v!))), const SizedBox(width: 10), Expanded(flex: 3, child: TextField(onChanged: (v) => cpfCnpj = v, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Seu CPF ou CNPJ", border: OutlineInputBorder(), helperText: "Somente números")))]), const SizedBox(height: 10),
          TextField(onChanged: (v) => faturamento = v.replaceAll(',', '.'), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Faturamento / Renda Mensal Declarada", prefixText: "R\$ ", border: OutlineInputBorder(), helperText: "Exigência de segurança do Banco Central")), const SizedBox(height: 10),
          Row(children: [Expanded(child: TextField(onChanged: (v) => nascimento = v, keyboardType: TextInputType.number, inputFormatters: [DataFormatter()], decoration: const InputDecoration(labelText: "Data de Nascimento (Ou de Fundação)", hintText: "DD/MM/AAAA", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(onChanged: (v) => telefone = v, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Celular (Com DDD)", border: OutlineInputBorder())))]), const SizedBox(height: 10),
          Row(children: [Expanded(flex: 1, child: TextField(onChanged: (v) => cep = v, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "CEP (Só números)", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(flex: 2, child: TextField(onChanged: (v) => bairro = v, decoration: const InputDecoration(labelText: "Nome do Bairro", border: OutlineInputBorder())))]), const SizedBox(height: 10),
          TextField(onChanged: (v) => endereco = v, decoration: const InputDecoration(labelText: "Logradouro (Rua, Avenida, etc)", border: OutlineInputBorder())), const SizedBox(height: 10),
          Row(children: [Expanded(child: TextField(onChanged: (v) => numero = v, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Número", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(child: TextField(onChanged: (v) => complemento = v, decoration: const InputDecoration(labelText: "Complemento (Opcional)", border: OutlineInputBorder())))]),
        ])),
        actions: [
          if (!criando) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: criando ? null : () async {
            if (!aceitouAvisoLegal) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Você deve ler e aceitar o Aviso Legal antes de prosseguir."))); return; }
            if ([nomeLegal, cpfCnpj, nascimento, telefone, cep, endereco, numero, bairro, faturamento].any((s) => s.isEmpty)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos obrigatórios, incluindo Renda/Faturamento."))); return; }
            setStateSB(() => criando = true);
            try {
              final user = FirebaseAuth.instance.currentUser;
              final response = await http.post(Uri.parse('https://us-central1-logichome-a9808.cloudfunctions.net/criarSubcontaAdministradora'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${user != null ? await user.getIdToken() : ''}'}, body: jsonEncode({'data': {'nome': nomeLegal, 'email': user!.email, 'cpfCnpj': cpfCnpj, 'nascimento': nascimento, 'tipoEmpresa': tipoEmpresa, 'telefone': telefone, 'cep': cep, 'endereco': endereco, 'numero': numero, 'complemento': complemento, 'bairro': bairro, 'faturamento': faturamento}}));
              if (response.statusCode == 200) {
                final result = jsonDecode(response.body)['result'] ?? jsonDecode(response.body)['data'];
                if (result != null && result['sucesso'] == true) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Conta bancária criada com sucesso!"), backgroundColor: Colors.green)); Navigator.pop(ctx); } } else throw Exception(result?['erro'] ?? "Falha relatada pelo Asaas.");
              } else { String err = response.body; try { final j = jsonDecode(response.body); if (j['error'] != null) err = j['error']['message'] ?? err; } catch(_) {} throw Exception("Erro: $err"); }
            } catch (e) { 
              if (mounted) { 
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); 
                setStateSB(() => criando = false); 
              } 
            }
          }, child: criando ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("CRIAR CONTA ASAAS"))
        ],
      );
    }));
  }

  @override
  void initState() { super.initState(); _tiposMultaStream = FirebaseFirestore.instance.collection('tipos_multa').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots(); _carregarFinanceiroDoMes(DateTime.now()); }

  Future<void> _selecionarVencimento() async {
    final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) setState(() => _dataVencimento = picked);
  }

  void _gerarCobrancaEmLote() async {
    if (_valorCtrl.text.isEmpty || _dataVencimento == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha o valor base e a data de vencimento."))); return; }
    showDialog(context: context, builder: (ctx) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: const Text("Gerar Lote de Boletos"), content: Text("Atenção: O sistema irá gerar um boleto para cada morador no valor base de R\$ ${_valorCtrl.text}.\n\nSe o morador tiver multas ou aluguéis pendentes, esses valores serão SOMADOS automaticamente ao boleto dele!\n\nVencimento: ${DateFormat('dd/MM/yyyy').format(_dataVencimento!)}"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), LogicNeonButton(corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: () async {
        Navigator.pop(ctx); setState(() => _processando = true);
        try {
          final token = FirebaseAuth.instance.currentUser != null ? await FirebaseAuth.instance.currentUser!.getIdToken() : '';
          final response = await http.post(Uri.parse('https://us-central1-logichome-a9808.cloudfunctions.net/gerarLoteFaturasMoradores'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({'data': {'sindico_vinculado': widget.emailSindico, 'valor': _valorCtrl.text.replaceAll(',', '.'), 'vencimento': _dataVencimento!.toIso8601String(), 'criado_por': operadorLogado, 'incluir_multas_pendentes': true}}));
          if (response.statusCode == 200) { final result = jsonDecode(response.body)['result'] ?? jsonDecode(response.body)['data']; if (result != null && result['sucesso'] == true) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sucesso! ${result['total'] ?? ''} Boletos gerados e enviados."), backgroundColor: Colors.green)); } else throw Exception(result?['erro'] ?? "Falha relatada pelo servidor Asaas."); } else { String err = response.body; try { final j = jsonDecode(response.body); if (j['error'] != null) err = j['error']['message'] ?? err; } catch(_) {} throw Exception("O servidor recusou a operação: $err"); }
        } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); } finally { if (mounted) setState(() => _processando = false); }
      }, child: const Text("GERAR FATURAS", style: TextStyle(color: Colors.white)))]);
    });
  }

  void _modalCriarTipoMulta({DocumentSnapshot? doc}) {
    final docData = doc != null ? doc.data() as Map<String, dynamic> : null;
    String nome = docData != null ? docData['nome'] : "", valorStr = docData != null ? docData['valor_padrao'].toString() : "";
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) => AlertDialog(title: Text(doc == null ? "Nova Regra de Multa/Taxa" : "Editar Multa"), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: TextEditingController(text: nome), onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: "Motivo (Ex: Som Alto)")), const SizedBox(height: 10), TextField(controller: TextEditingController(text: valorStr), onChanged: (v) => valorStr = v.replaceAll(',', '.'), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: "Valor Padrão (R\$)", helperText: "Use o sinal '-' na frente para dar estorno/crédito."))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(onPressed: () async { if (nome.isNotEmpty && valorStr.isNotEmpty) { if (doc == null) await FirebaseFirestore.instance.collection('tipos_multa').add({'sindico_vinculado': widget.emailSindico, 'nome': nome, 'valor_padrao': double.parse(valorStr)}); else await doc.reference.update({'nome': nome, 'valor_padrao': double.parse(valorStr)}); if (mounted) Navigator.pop(ctx); } }, child: const Text("SALVAR"))])));
  }

  void _modalLancarInfracao() async {
    final tiposSnap = await FirebaseFirestore.instance.collection('tipos_multa').where('sindico_vinculado', isEqualTo: widget.emailSindico).get(), moradoresSnap = await FirebaseFirestore.instance.collection('usuarios').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('perfil', isEqualTo: 'morador').get();
    if (tiposSnap.docs.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Crie pelo menos um Tipo de Multa primeiro!"), backgroundColor: Colors.orange)); return; }
    String? idMoradorSel, idTipoMultaSel; String descricao = ""; Uint8List? fotoProva; bool salvando = false;
    if (!mounted) return;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const Row(children: [Icon(Icons.gavel, color: Colors.red), SizedBox(width: 10), Text("Lançar Multa ou Estorno")]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [DropdownButtonFormField<String>(isExpanded: true, decoration: const InputDecoration(labelText: "Selecione a Unidade (Morador)", border: OutlineInputBorder()), items: moradoresSnap.docs.map((m) => DropdownMenuItem(value: m.id, child: Text("${m['nome']} (B:${m['bloco']} AP:${m['ap']})"))).toList(), onChanged: (v) => setStateSB(() => idMoradorSel = v)), const SizedBox(height: 15), DropdownButtonFormField<String>(isExpanded: true, decoration: const InputDecoration(labelText: "Qual a infração/crédito?", border: OutlineInputBorder()), items: tiposSnap.docs.map((t) => DropdownMenuItem(value: t.id, child: Text("${t['nome']} - R\$ ${t['valor_padrao']}" ))).toList(), onChanged: (v) => setStateSB(() => idTipoMultaSel = v)), const SizedBox(height: 15), TextField(onChanged: (v) => descricao = v, maxLines: 3, decoration: const InputDecoration(labelText: "Descreva o motivo (Irá no extrato do morador)", border: OutlineInputBorder())), const SizedBox(height: 15), const Text("Prova Opcional (Foto):", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), InkWell(onTap: () async { final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70); if (photo != null) setStateSB(() async => fotoProva = await photo.readAsBytes()); }, child: Container(height: 120, width: double.infinity, decoration: BoxDecoration(color: fotoProva != null ? Colors.green.withValues(alpha:0.2) : colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10), border: Border.all(color: colorScheme.outline)), child: fotoProva == null ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt), Text("Tirar Foto")]) : Image.memory(fotoProva!, fit: BoxFit.cover)))])),
        actions: [
          if (!salvando) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: salvando ? null : () async {
            if (idMoradorSel == null || idTipoMultaSel == null || descricao.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha morador, tipo e descrição."))); return; }
            setStateSB(() => salvando = true);
            try {
              final moradorData = moradoresSnap.docs.firstWhere((d) => d.id == idMoradorSel).data(), multaData = tiposSnap.docs.firstWhere((d) => d.id == idTipoMultaSel).data();
              String urlFoto = ""; if (fotoProva != null) { final ref = FirebaseStorage.instance.ref().child("multas/${widget.emailSindico}/${const Uuid().v4()}.jpg"); await ref.putData(fotoProva!, SettableMetadata(contentType: 'image/jpeg')); urlFoto = await ref.getDownloadURL(); }
              final novaRef = await FirebaseFirestore.instance.collection('cobrancas_extras').add({'sindico_vinculado': widget.emailSindico, 'email_morador': idMoradorSel, 'nome_morador': moradorData['nome'], 'bloco': moradorData['bloco'], 'ap': moradorData['ap'], 'tipo': 'multa', 'titulo': 'Lançamento: ${multaData['nome']}', 'descricao': descricao, 'valor': multaData['valor_padrao'], 'status': 'pendente_faturamento', 'foto_prova_url': urlFoto, 'data_criacao': FieldValue.serverTimestamp()});
              
              final chaveMes = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}";
              if (_multasCachePorMes.containsKey(chaveMes)) {
                final novaMulta = {'id': novaRef.id, 'sindico_vinculado': widget.emailSindico, 'email_morador': idMoradorSel, 'nome_morador': moradorData['nome'], 'bloco': moradorData['bloco'], 'ap': moradorData['ap'], 'tipo': 'multa', 'titulo': 'Lançamento: ${multaData['nome']}', 'descricao': descricao, 'valor': multaData['valor_padrao'], 'status': 'pendente_faturamento', 'foto_prova_url': urlFoto, 'data_criacao': DateTime.now().toIso8601String()};
                setState(() => _multasCachePorMes[chaveMes]!.add(novaMulta));
                final prefs = await SharedPreferences.getInstance(), hdDados = prefs.getString('fin_${widget.emailSindico}_$chaveMes') ?? '';
                if (hdDados.isNotEmpty) { final cofre = jsonDecode(hdDados); cofre['multas'].add(novaMulta); await prefs.setString('fin_${widget.emailSindico}_$chaveMes', jsonEncode(cofre)); }
              }
              if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cobrança/Crédito lançado! Aparecerá no próximo boleto."), backgroundColor: Colors.green)); }
            } catch (e) { setStateSB(() => salvando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red)); }
          }, child: salvando ? const CircularProgressIndicator(color: Colors.white) : const Text("LANCAR NO SISTEMA"))
        ],
      );
    }));
  }

  void _modalLancarDespesa() {
    String titulo = "", descricao = "", valorStr = ""; DateTime dataDaDespesa = DateTime.now(); bool salvando = false;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(title: const Row(children: [Icon(Icons.money_off, color: Colors.red), SizedBox(width: 10), Text("Lançar Despesa")]), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(onChanged: (v) => titulo = v, decoration: const InputDecoration(labelText: "Título (Ex: Conta de Água)", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(onChanged: (v) => descricao = v, maxLines: 2, decoration: const InputDecoration(labelText: "Descrição/Referência", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(onChanged: (v) => valorStr = v.replaceAll(',', '.'), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Valor (R\$)", prefixText: "R\$ ", border: OutlineInputBorder())), const SizedBox(height: 15), InkWell(onTap: () async { final picked = await showDatePicker(context: context, initialDate: dataDaDespesa, firstDate: DateTime(2020), lastDate: DateTime.now()); if (picked != null) setStateSB(() => dataDaDespesa = picked); }, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Data do Pagamento: ${DateFormat('dd/MM/yyyy').format(dataDaDespesa)}", style: const TextStyle(fontWeight: FontWeight.bold)), const Icon(Icons.calendar_month)])))])), actions: [if (!salvando) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError), onPressed: salvando ? null : () async { if (titulo.isEmpty || valorStr.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha o título e o valor!"))); return; } setStateSB(() => salvando = true); try { await FirebaseFirestore.instance.collection('despesas_condominio').add({'sindico_vinculado': widget.emailSindico, 'titulo': titulo, 'descricao': descricao, 'valor': double.parse(valorStr), 'data_pagamento': Timestamp.fromDate(dataDaDespesa), 'data_registro': FieldValue.serverTimestamp()}); if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Despesa registrada com sucesso!"), backgroundColor: Colors.green)); } } catch (e) { setStateSB(() => salvando = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red)); } }, child: salvando ? const CircularProgressIndicator(color: Colors.white) : const Text("REGISTRAR DESPESA"))]
        );
    }));
  }

  Future<void> _gerarPdfBalancete({required double totalReceitas, required double totalDespesas, required double totalInadimplente, required double saldo, required String mesAnoFormatado, required List<Map<String, dynamic>> receitasPagos, required List<Map<String, dynamic>> despesasLista, required List<Map<String, dynamic>> inadimplentesLista}) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(32), build: (context) => [
      pw.Header(level: 0, child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Balancete Financeiro Condominial", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)), pw.Text(mesAnoFormatado, style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700))])), pw.SizedBox(height: 20),
      pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text("RESUMO DO MÊS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)), pw.Divider(), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Arrecadado (Receitas):"), pw.Text("R\$ ${totalReceitas.toStringAsFixed(2)}", style: const pw.TextStyle(color: PdfColors.green))]), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Total Gasto (Despesas):"), pw.Text("R\$ ${totalDespesas.toStringAsFixed(2)}", style: const pw.TextStyle(color: PdfColors.red))]), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Inadimplência Projetada:"), pw.Text("R\$ ${totalInadimplente.toStringAsFixed(2)}", style: const pw.TextStyle(color: PdfColors.orange))]), pw.Divider(), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("SALDO LÍQUIDO DO MÊS:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("R\$ ${saldo.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: saldo >= 0 ? PdfColors.green : PdfColors.red))])])), pw.SizedBox(height: 30),
      pw.Text("1. RECEITAS (BOLETOS PAGOS)", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), pw.Divider(), if (receitasPagos.isEmpty) pw.Text("Nenhuma receita neste mês.", style: const pw.TextStyle(color: PdfColors.grey)), ...receitasPagos.map((r) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("${r['nome']} (AP ${r['ap']}) - Pago em: ${r['data_pgto']}"), pw.Text("R\$ ${r['valor'].toStringAsFixed(2)}")]))), pw.SizedBox(height: 30),
      pw.Text("2. DESPESAS E GASTOS", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), pw.Divider(), if (despesasLista.isEmpty) pw.Text("Nenhuma despesa neste mês.", style: const pw.TextStyle(color: PdfColors.grey)), ...despesasLista.map((d) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("${d['titulo']} - Data: ${d['data']}"), pw.Text("R\$ ${d['valor'].toStringAsFixed(2)}", style: const pw.TextStyle(color: PdfColors.red))]))), pw.SizedBox(height: 30),
      pw.Text("3. INADIMPLÊNCIA DO MÊS", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), pw.Divider(), if (inadimplentesLista.isEmpty) pw.Text("Nenhum devedor neste mês.", style: const pw.TextStyle(color: PdfColors.green)), ...inadimplentesLista.map((i) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("${i['nome']} (AP ${i['ap']}) - Vencido em: ${i['vencimento']}"), pw.Text("R\$ ${i['valor'].toStringAsFixed(2)}", style: const pw.TextStyle(color: PdfColors.orange))]))), pw.SizedBox(height: 50), pw.Center(child: pw.Text("Gerado pelo Sistema Logic Home ERP", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)))
    ]));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Balancete_${mesAnoFormatado.replaceAll('/', '_')}');
  }

  Future<void> _importarPlanilhaCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
      if (result?.files.first.bytes == null) return;
      showDialog(context: context, barrierDismissible: false, builder: (c) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 15), Text("Processando e blindando dados...")])));
      final linhas = utf8.decode(result!.files.first.bytes!).split('\n'), snapAtuais = await FirebaseFirestore.instance.collection('unidades_base').where('sindico_vinculado', isEqualTo: widget.emailSindico).get(), bancoAtual = {for (var doc in snapAtuais.docs) doc.id: doc.data()};
      var batch = FirebaseFirestore.instance.batch(); int countBatch = 0, processados = 0;

      for (int i = 1; i < linhas.length; i++) {
        final linha = linhas[i].trim(); if (linha.isEmpty) continue;
        final colunas = linha.split(';'); if (colunas.length < 5) continue;
        final bloco = colunas[0].trim().toUpperCase(), ap = colunas[1].trim(), nome = colunas[2].trim(), cpf = colunas[3].replaceAll(RegExp(r'[^0-9]'), ''), email = colunas[4].trim().toLowerCase(), tel = colunas.length > 5 ? colunas[5].trim() : '';
        if (ap.isEmpty || nome.isEmpty || cpf.isEmpty || email.isEmpty) continue;
        
        final docId = "${widget.emailSindico}_${bloco}_$ap".replaceAll(' ', ''), novosDados = {'sindico_vinculado': widget.emailSindico, 'bloco': bloco, 'ap': ap, 'nome_proprietario': nome, 'cpf_cnpj': cpf, 'email': email, 'telefone': tel, 'atualizado_em': FieldValue.serverTimestamp(), 'atualizado_por': "$operadorLogado (Planilha Excel)"}, refUnidade = FirebaseFirestore.instance.collection('unidades_base').doc(docId);

        if (bancoAtual.containsKey(docId)) {
           final velhos = bancoAtual[docId]!;
           if (velhos['cpf_cnpj'] != cpf || velhos['email'] != email || velhos['nome_proprietario'] != nome) {
              batch.set(FirebaseFirestore.instance.collection('auditoria_unidades').doc(), {'sindico_vinculado': widget.emailSindico, 'bloco': bloco, 'ap': ap, 'dados_antigos': velhos, 'dados_novos': novosDados, 'data_alteracao': FieldValue.serverTimestamp(), 'alterado_por': "$operadorLogado (Importação Planilha)"});
              batch.update(refUnidade, novosDados); countBatch += 2;
           }
        } else { batch.set(refUnidade, novosDados); countBatch++; }
        processados++;
        if (countBatch > 450) { await batch.commit(); batch = FirebaseFirestore.instance.batch(); countBatch = 0; }
      }
      if (countBatch > 0) await batch.commit();
      if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$processados unidades importadas e auditadas com sucesso!"), backgroundColor: Colors.green)); }
    } catch (e) { if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro na leitura: Certifique-se que o arquivo é um CSV separado por Ponto e Vírgula (;). Detalhe: $e"), backgroundColor: Colors.red)); } }
  }

  void _modalEditarProprietario({DocumentSnapshot? doc}) {
    final Map<String, dynamic> docData = doc != null ? doc.data() as Map<String, dynamic> : {};
    String bloco = doc != null ? docData['bloco'] : "", ap = doc != null ? docData['ap'] : "", nome = doc != null ? docData['nome_proprietario'] : "", cpfCnpj = doc != null ? docData['cpf_cnpj'] : "", email = doc != null ? docData['email'] : "", telefone = doc != null ? docData['telefone'] : ""; bool processando = false;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Row(children: [Icon(Icons.real_estate_agent, color: colorScheme.primary), const SizedBox(width: 10), Text(doc == null ? "Cadastrar Unidade" : "Editar Proprietário")]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Estes são os dados OFICIAIS de cobrança. O boleto do Asaas será emitido para este CPF e enviado para este e-mail.", style: TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 15),
          Row(children: [Expanded(child: TextField(controller: TextEditingController(text: bloco), onChanged: (v) => bloco = v.trim().toUpperCase(), decoration: const InputDecoration(labelText: "Bloco", border: OutlineInputBorder()), enabled: doc == null)), const SizedBox(width: 10), Expanded(child: TextField(controller: TextEditingController(text: ap), onChanged: (v) => ap = v.trim(), decoration: const InputDecoration(labelText: "Apartamento", border: OutlineInputBorder()), enabled: doc == null))]), const SizedBox(height: 10),
          TextField(controller: TextEditingController(text: nome), onChanged: (v) => nome = v, decoration: const InputDecoration(labelText: "Nome do Proprietário", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: TextEditingController(text: cpfCnpj), onChanged: (v) => cpfCnpj = v, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "CPF / CNPJ", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: TextEditingController(text: email), onChanged: (v) => email = v.toLowerCase().trim(), keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "E-mail de Faturamento", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: TextEditingController(text: telefone), onChanged: (v) => telefone = v, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefone", border: OutlineInputBorder())),
        ])),
        actions: [
          if (!processando) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: processando ? null : () async {
            if (bloco.isEmpty || ap.isEmpty || nome.isEmpty || cpfCnpj.isEmpty || email.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos obrigatórios."))); return; }
            setStateSB(() => processando = true);
            try {
              final docId = "${widget.emailSindico}_${bloco}_$ap".replaceAll(' ', ''), novosDados = {'sindico_vinculado': widget.emailSindico, 'bloco': bloco, 'ap': ap, 'nome_proprietario': nome, 'cpf_cnpj': cpfCnpj.replaceAll(RegExp(r'[^0-9]'), ''), 'email': email, 'telefone': telefone, 'atualizado_em': FieldValue.serverTimestamp(), 'atualizado_por': operadorLogado};
              final batch = FirebaseFirestore.instance.batch(), refUnidade = FirebaseFirestore.instance.collection('unidades_base').doc(docId);
              if (doc != null) { batch.set(FirebaseFirestore.instance.collection('auditoria_unidades').doc(), {'sindico_vinculado': widget.emailSindico, 'bloco': bloco, 'ap': ap, 'dados_antigos': doc.data(), 'dados_novos': novosDados, 'data_alteracao': FieldValue.serverTimestamp(), 'alterado_por': operadorLogado}); batch.update(refUnidade, novosDados); } else batch.set(refUnidade, novosDados);
              await batch.commit(); if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unidade salva com sucesso!"), backgroundColor: Colors.green)); }
            } catch (e) { setStateSB(() => processando = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red)); }
          }, child: processando ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SALVAR BASE"))
        ],
      );
    }));
  }

  Widget _cardKpiFin(String titulo, double valor, Color cor, IconData icone) => Card(elevation: 2, shape: RoundedRectangleBorder(side: BorderSide(color: cor.withValues(alpha:0.5)), borderRadius: BorderRadius.circular(10)), child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: cor.withValues(alpha:0.2), shape: BoxShape.circle), child: Icon(icone, color: cor, size: 30)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)), const SizedBox(height: 5), FittedBox(fit: BoxFit.scaleDown, child: Text("R\$ ${valor.toStringAsFixed(2)}", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cor)))]))])));

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(length: 6, child: Column(children: [
      Padding(padding: const EdgeInsets.all(16.0), child: Align(alignment: Alignment.centerLeft, child: Text("ERP Financeiro do Condomínio", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.primary)))),
      TabBar(isScrollable: true, labelColor: colorScheme.primary, unselectedLabelColor: colorScheme.onSurfaceVariant, tabs: const [Tab(icon: Icon(Icons.dashboard), text: "Inadimplência"), Tab(icon: Icon(Icons.request_quote), text: "Lote de Boletos"), Tab(icon: Icon(Icons.warning), text: "Multas e Locações (Extras)"), Tab(icon: Icon(Icons.format_list_bulleted), text: "Catálogo de Valores"), Tab(icon: Icon(Icons.receipt_long), text: "Balancete Mensal"), Tab(icon: Icon(Icons.real_estate_agent), text: "Base de Proprietários")]),
      Expanded(child: TabBarView(children: [
        Builder(builder: (context) {
          if (_carregandoFinanceiro) return const Center(child: CircularProgressIndicator());
          final chaveMes = "${_mesFiltroDashboard.year}-${_mesFiltroDashboard.month.toString().padLeft(2, '0')}", docs = _faturasCachePorMes[chaveMes] ?? [];
          double totalPago = 0, totalPendente = 0; final hoje = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day), devedores = <Map<String, dynamic>>[], pagadores = <Map<String, dynamic>>[];
          for (var data in docs) {
            final pago = data['status'] == 'RECEIVED' || data['status'] == 'CONFIRMED', valor = (data['valor'] ?? 0).toDouble(), termo = _buscaDashboard.toLowerCase().trim();
            final blocoBusca = (data['bloco'] ?? '').toString().toLowerCase(), apBusca = (data['ap'] ?? '').toString().toLowerCase(), matchBlocoAp = blocoBusca.contains(termo) || apBusca.contains(termo) || "$blocoBusca/$apBusca".contains(termo) || "$blocoBusca-$apBusca".contains(termo) || "$blocoBusca $apBusca".contains(termo);
            if (termo.isNotEmpty && !(data['nome_morador'] ?? '').toString().toLowerCase().contains(termo) && !matchBlocoAp) continue;
            if (pago) { totalPago += valor; pagadores.add(data); } else { totalPendente += valor; devedores.add(data); }
          }
          final avisoTaxas = Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.blue.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withValues(alpha:0.5))), child: Row(children: [const Icon(Icons.info, color: Colors.blue), const SizedBox(width: 10), Expanded(child: Text.rich(TextSpan(text: "Aviso de Transparência: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 12), children: [TextSpan(text: "Os valores abaixo representam a Receita Bruta. Ao ser pago, o sistema desconta R\$ 1,99 (Licença do Software) e a tarifa do Asaas (PIX/Boleto). O valor líquido já cai direto na conta da Administradora.", style: TextStyle(fontWeight: FontWeight.normal, color: Colors.blue.shade800))])))]));
          final controlesFiltro = Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: Row(children: [Expanded(child: TextField(onChanged: (v) => setState(() => _buscaDashboard = v), decoration: const InputDecoration(labelText: "Buscar Morador/Unidade", prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true))), const SizedBox(width: 10), IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () { setState(() => _mesFiltroDashboard = DateTime(_mesFiltroDashboard.year, _mesFiltroDashboard.month - 1, 1)); _carregarFinanceiroDoMes(_mesFiltroDashboard); }), Text(DateFormat('MM/yyyy').format(_mesFiltroDashboard), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 18), onPressed: () { setState(() => _mesFiltroDashboard = DateTime(_mesFiltroDashboard.year, _mesFiltroDashboard.month + 1, 1)); _carregarFinanceiroDoMes(_mesFiltroDashboard); })]));
          final listaDevedoresUi = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_cardKpiFin("A Receber / Pendentes", totalPendente, Colors.red, Icons.trending_down), const SizedBox(height: 10), const Text("🔥 Unidades Pendentes/Devedoras", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), const Divider(), if (devedores.isEmpty) const Padding(padding: EdgeInsets.all(10), child: Text("Nenhum boleto pendente neste mês!")), ...devedores.map((data) { bool vencido = false; try { vencido = DateTime.parse(data['vencimento']).isBefore(hoje); } catch(_) {} return Card(shape: RoundedRectangleBorder(side: BorderSide(color: (vencido ? Colors.red : Colors.orange).withValues(alpha:0.3))), child: ListTile(dense: true, leading: Icon(vencido ? Icons.block : Icons.schedule, color: vencido ? Colors.red : Colors.orange), title: Text("${data['nome_morador']} (B: ${data['bloco']} AP: ${data['ap']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text("Vencimento: ${data['vencimento']}", style: const TextStyle(fontSize: 10)), trailing: Text("R\$ ${data['valor']}", style: TextStyle(color: vencido ? Colors.red : Colors.orange, fontWeight: FontWeight.bold)))); })]);
          final listaPagadoresUi = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_cardKpiFin("Receita do Mês", totalPago, Colors.green, Icons.trending_up), const SizedBox(height: 10), const Text("✅ Faturas Pagas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)), const Divider(), if (pagadores.isEmpty) const Padding(padding: EdgeInsets.all(10), child: Text("Nenhuma fatura paga neste mês!")), ...pagadores.map((data) { DateTime? dt; try { if (data['data_pagamento'] != null) dt = data['data_pagamento'] is Timestamp ? (data['data_pagamento'] as Timestamp).toDate() : DateTime.parse(data['data_pagamento']); else dt = DateTime.parse(data['vencimento']); } catch(_) {} return Card(shape: RoundedRectangleBorder(side: BorderSide(color: Colors.green.withValues(alpha:0.3))), child: ListTile(dense: true, leading: const Icon(Icons.check_circle, color: Colors.green), title: Text("${data['nome_morador']} (B: ${data['bloco']} AP: ${data['ap']})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), subtitle: Text("Pago em: ${dt != null ? DateFormat('dd/MM').format(dt) : 'N/D'}", style: const TextStyle(fontSize: 10)), trailing: Text("R\$ ${data['valor']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)))); })]);
          return LayoutBuilder(builder: (context, constraints) => Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [avisoTaxas, controlesFiltro, Expanded(child: constraints.maxWidth < 800 ? SingleChildScrollView(child: Column(children: [listaDevedoresUi, const SizedBox(height: 30), listaPagadoresUi])) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: SingleChildScrollView(child: listaDevedoresUi)), const SizedBox(width: 20), Expanded(child: SingleChildScrollView(child: listaPagadoresUi))]))])));
        }),
        StreamBuilder<DocumentSnapshot>(stream: FirebaseFirestore.instance.collection('usuarios').doc(FirebaseAuth.instance.currentUser!.email).snapshots(), builder: (context, snapAdmin) {
          if (!snapAdmin.hasData) return const Center(child: CircularProgressIndicator());
          final adminData = snapAdmin.data!.data() as Map<String, dynamic>, temContaBancaria = adminData['asaas_api_key'] != null;
          return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
            if (!temContaBancaria) Card(color: colorScheme.errorContainer, child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [Icon(Icons.warning, color: colorScheme.error, size: 50), const SizedBox(height: 10), Text("CONTA BANCÁRIA NÃO CONFIGURADA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.error)), const SizedBox(height: 5), Text("Para emitir boletos e receber o dinheiro dos condomínios na sua conta, você precisa abrir uma carteira digital integrada ao Asaas.", textAlign: TextAlign.center, style: TextStyle(color: colorScheme.onErrorContainer)), const SizedBox(height: 20), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError, padding: const EdgeInsets.all(20)), icon: const Icon(Icons.account_balance), label: const Text("CRIAR CONTA BANCÁRIA AGORA", style: TextStyle(fontWeight: FontWeight.bold)), onPressed: _modalCriarContaBancaria)]))),
            if (temContaBancaria) ...[
              Card(elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.green.withValues(alpha:0.5), width: 2)), child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const Icon(Icons.account_balance_wallet, color: Colors.green, size: 30), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Conta Digital Asaas Ativa", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)), Text("ID da Carteira (Wallet): ${adminData['asaas_wallet_id'] ?? 'N/D'}", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12))]))]), const SizedBox(height: 15), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.withValues(alpha:0.5))), child: Row(children: [const Icon(Icons.info_outline, color: Colors.orange), const SizedBox(width: 10), Expanded(child: Text("Por questões de segurança (LGPD e Banco Central), a edição de dados bancários, envio de documentos e resgate do seu dinheiro devem ser feitos exclusivamente acessando o site oficial do Asaas.", style: TextStyle(color: Colors.orange.shade800, fontSize: 12)))])), const SizedBox(height: 15), SizedBox(width: double.infinity, child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green), padding: const EdgeInsets.symmetric(vertical: 15)), icon: const Icon(Icons.open_in_new), label: const Text("ACESSAR PAINEL DO ASAAS", style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () async { if (await canLaunchUrl(Uri.parse('https://www.asaas.com/login'))) await launchUrl(Uri.parse('https://www.asaas.com/login'), mode: LaunchMode.externalApplication); }))]))), const SizedBox(height: 20),
              Card(color: colorScheme.surfaceContainerHighest, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Gerar Cobrança em Lote (Mensalidade)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 15), LayoutBuilder(builder: (context, constraints) { final isMobile = constraints.maxWidth < 600, campoValor = TextField(controller: _valorCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: "Taxa Base (R\$)", border: OutlineInputBorder(), prefixText: "R\$ ")), campoData = InkWell(onTap: _selecionarVencimento, child: Container(height: 56, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(border: Border.all(color: colorScheme.outline), borderRadius: BorderRadius.circular(4)), alignment: Alignment.centerLeft, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_dataVencimento == null ? "Data de Vencimento" : DateFormat('dd/MM/yyyy').format(_dataVencimento!), style: TextStyle(color: _dataVencimento == null ? colorScheme.onSurfaceVariant : colorScheme.onSurface, fontSize: 16)), Icon(Icons.calendar_month, color: colorScheme.primary)]))), botaoAcao = SizedBox(height: 56, width: isMobile ? double.infinity : null, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), icon: _processando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send), label: Text(_processando ? "GERANDO..." : "GERAR E ENVIAR", style: const TextStyle(fontWeight: FontWeight.bold)), onPressed: _processando ? null : _gerarCobrancaEmLote)); return isMobile ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [campoValor, const SizedBox(height: 15), campoData, const SizedBox(height: 15), botaoAcao]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: campoValor), const SizedBox(width: 15), Expanded(child: campoData), const SizedBox(width: 15), Expanded(child: botaoAcao)]); })])))
            ]
          ]));
        }),
        Scaffold(floatingActionButton: FloatingActionButton.extended(onPressed: _modalLancarInfracao, icon: const Icon(Icons.gavel), label: const Text("Lançar Multa / Crédito")), body: Column(children: [Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20), color: colorScheme.surfaceContainerHighest, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () { setState(() => _mesFiltroMultas = DateTime(_mesFiltroMultas.year, _mesFiltroMultas.month - 1, 1)); _carregarFinanceiroDoMes(_mesFiltroMultas); }), Text("Mês: ${DateFormat('MM/yyyy').format(_mesFiltroMultas)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 18), onPressed: () { setState(() => _mesFiltroMultas = DateTime(_mesFiltroMultas.year, _mesFiltroMultas.month + 1, 1)); _carregarFinanceiroDoMes(_mesFiltroMultas); })])), Expanded(child: Builder(builder: (context) { if (_carregandoFinanceiro) return const Center(child: CircularProgressIndicator()); final chaveMes = "${_mesFiltroMultas.year}-${_mesFiltroMultas.month.toString().padLeft(2, '0')}", multasDoMes = _multasCachePorMes[chaveMes] ?? []; if (multasDoMes.isEmpty) return const Center(child: Text("Nenhum lançamento extra neste mês.")); return ListView.builder(padding: const EdgeInsets.all(16), itemCount: multasDoMes.length, itemBuilder: (c, i) { final data = multasDoMes[i], isMulta = data['tipo'] == 'multa', isFaturado = data['status'] == 'faturado', isEstorno = data['valor'] < 0; return Card(shape: RoundedRectangleBorder(side: BorderSide(color: isMulta ? Colors.red.withValues(alpha:0.5) : Colors.orange.withValues(alpha:0.5))), child: ListTile(leading: Icon(isMulta ? Icons.gavel : Icons.deck, color: isMulta ? Colors.red : Colors.orange, size: 30), title: Text("${data['titulo']} - R\$ ${data['valor']}", style: TextStyle(fontWeight: FontWeight.bold, color: isEstorno ? Colors.blue : null)), subtitle: Text("Morador: ${data['nome_morador']} (AP: ${data['ap']})\n${data['descricao']}"), trailing: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [Text(isFaturado ? "NO BOLETO" : "AGUARD. FATURA", style: TextStyle(color: isFaturado ? Colors.green : Colors.grey, fontWeight: FontWeight.bold, fontSize: 10)), if (!isFaturado) IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 18), onPressed: () async { await FirebaseFirestore.instance.collection('cobrancas_extras').doc(data['id']).delete(); setState(() => multasDoMes.removeAt(i)); final prefs = await SharedPreferences.getInstance(), hdDados = prefs.getString('fin_${widget.emailSindico}_$chaveMes') ?? ''; if (hdDados.isNotEmpty) { final cofre = jsonDecode(hdDados); cofre['multas'].removeWhere((m) => m['id'] == data['id']); await prefs.setString('fin_${widget.emailSindico}_$chaveMes', jsonEncode(cofre)); } })])))); }); }))])),
        Scaffold(floatingActionButton: FloatingActionButton.extended(onPressed: () => _modalCriarTipoMulta(), icon: const Icon(Icons.add), label: const Text("Nova Regra")), body: StreamBuilder<QuerySnapshot>(stream: _tiposMultaStream, builder: (context, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, itemBuilder: (c, i) { final doc = snap.data!.docs[i]; return Card(child: ListTile(title: Text(doc['nome'], style: const TextStyle(fontWeight: FontWeight.bold)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("R\$ ${doc['valor_padrao']}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(width: 15), IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _modalCriarTipoMulta(doc: doc)), IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => doc.reference.delete())]))); }); })),
        Builder(builder: (context) {
          if (_carregandoFinanceiro) return const Center(child: CircularProgressIndicator());
          final chaveMes = "${_mesFiltroPrestacao.year}-${_mesFiltroPrestacao.month.toString().padLeft(2, '0')}", faturasDoMes = _faturasCachePorMes[chaveMes] ?? [], despesasDoMes = _despesasCachePorMes[chaveMes] ?? [], mesAnoFormat = DateFormat('MM/yyyy').format(_mesFiltroPrestacao);
          double totalReceitas = 0, totalDespesas = 0, totalInadimplente = 0; final listaReceitas = <Map<String, dynamic>>[], listaDespesas = <Map<String, dynamic>>[], listaInadimplentes = <Map<String, dynamic>>[];
          for (var data in faturasDoMes) { final pago = data['status'] == 'RECEIVED' || data['status'] == 'CONFIRMED', valor = (data['valor'] ?? 0).toDouble(); try { if (pago) { DateTime dtPgto = data['data_pagamento'] != null ? (data['data_pagamento'] is Timestamp ? (data['data_pagamento'] as Timestamp).toDate() : DateTime.parse(data['data_pagamento'])) : DateTime.parse(data['vencimento']); totalReceitas += valor; listaReceitas.add({'nome': data['nome_morador'], 'ap': data['ap'], 'valor': valor, 'data_pgto': DateFormat('dd/MM/yyyy').format(dtPgto)}); } else { totalInadimplente += valor; listaInadimplentes.add({'nome': data['nome_morador'], 'ap': data['ap'], 'valor': valor, 'vencimento': DateFormat('dd/MM/yyyy').format(DateTime.parse(data['vencimento']))}); } } catch (_) {} }
          for (var data in despesasDoMes) { try { if (data['data_pagamento'] != null) { final valor = (data['valor'] ?? 0).toDouble(); totalDespesas += valor; listaDespesas.add({'titulo': data['titulo'], 'valor': valor, 'data': DateFormat('dd/MM/yyyy').format(data['data_pagamento'] is Timestamp ? (data['data_pagamento'] as Timestamp).toDate() : DateTime.parse(data['data_pagamento']))}); } } catch (_) {} }
          final saldoFinal = totalReceitas - totalDespesas;

          return Column(children: [
            Container(padding: const EdgeInsets.all(12), color: Colors.blue.withValues(alpha:0.1), child: Row(children: [const Icon(Icons.info_outline, color: Colors.blue), const SizedBox(width: 10), Expanded(child: Text("Transparência: O Balancete reflete os Valores Brutos das taxas condominiais pagas pelos moradores. Para ver os valores exatos dos descontos bancários do Asaas e da licença (R\$ 1,99), acesse o extrato detalhado na sua conta Asaas.", style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold)))])),
            Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20), color: colorScheme.surfaceContainerHighest, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () { setState(() => _mesFiltroPrestacao = DateTime(_mesFiltroPrestacao.year, _mesFiltroPrestacao.month - 1, 1)); _carregarFinanceiroDoMes(_mesFiltroPrestacao); }), Text("Balancete: $mesAnoFormat", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 18), onPressed: () { setState(() => _mesFiltroPrestacao = DateTime(_mesFiltroPrestacao.year, _mesFiltroPrestacao.month + 1, 1)); _carregarFinanceiroDoMes(_mesFiltroPrestacao); })])),
            LayoutBuilder(builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600, btnDespesa = ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError, padding: const EdgeInsets.all(15)), icon: const Icon(Icons.money_off), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("LANÇAR DESPESA / GASTO", style: TextStyle(fontWeight: FontWeight.bold))), onPressed: _modalLancarDespesa), btnPdf = ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary, padding: const EdgeInsets.all(15)), icon: const Icon(Icons.print), label: const FittedBox(fit: BoxFit.scaleDown, child: Text("GERAR PDF PRESTAÇÃO", style: TextStyle(fontWeight: FontWeight.bold))), onPressed: () => _gerarPdfBalancete(totalReceitas: totalReceitas, totalDespesas: totalDespesas, totalInadimplente: totalInadimplente, saldo: saldoFinal, mesAnoFormatado: mesAnoFormat, receitasPagos: listaReceitas, despesasLista: listaDespesas, inadimplentesLista: listaInadimplentes)), cardRec = _cardKpiFin("Receitas Pagas", totalReceitas, Colors.green, Icons.arrow_downward), cardDes = _cardKpiFin("Despesas Mês", totalDespesas, Colors.red, Icons.arrow_upward), cardSal = _cardKpiFin("Saldo do Mês", saldoFinal, saldoFinal >= 0 ? Colors.blue : Colors.red, Icons.account_balance);
              return isMobile ? Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [btnDespesa, const SizedBox(height: 10), btnPdf, const SizedBox(height: 20), cardRec, const SizedBox(height: 10), cardDes, const SizedBox(height: 10), cardSal])) : Column(children: [Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [Expanded(child: btnDespesa), const SizedBox(width: 15), Expanded(child: btnPdf)])), Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Row(children: [Expanded(child: cardRec), const SizedBox(width: 10), Expanded(child: cardDes), const SizedBox(width: 10), Expanded(child: cardSal)]))]);
            }),
            Expanded(child: listaDespesas.isEmpty ? const Center(child: Text("Nenhuma despesa lançada neste mês.", style: TextStyle(color: Colors.grey))) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: listaDespesas.length, itemBuilder: (c, i) { final d = listaDespesas[i]; return Card(child: ListTile(leading: const Icon(Icons.money_off, color: Colors.red), title: Text(d['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Data: ${d['data']}"), trailing: Text("R\$ ${d['valor'].toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)))); }))
          ]);
        }),
        _abaBaseProprietarios()
      ]))
    ]));
  }

  Widget _abaBaseProprietarios() {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: Row(mainAxisSize: MainAxisSize.min, children: [FloatingActionButton.extended(heroTag: "btn_upload", backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Theme.of(context).colorScheme.onSecondary, onPressed: () { showDialog(context: context, builder: (c) => AlertDialog(title: const Row(children: [Icon(Icons.upload_file, color: Colors.blue), SizedBox(width: 10), Text("Importar Planilha CSV")]), content: const Text("Salve seu Excel no formato 'CSV UTF-8 (separado por vírgula)'.\n\nO arquivo deve conter as colunas exatamente nesta ordem (sem cabeçalho na primeira linha ou pulando ele na leitura):\n\n1. Bloco\n2. Apartamento\n3. Nome do Proprietário\n4. CPF / CNPJ (Só números)\n5. E-mail Financeiro\n6. Telefone (Opcional)\n\nSe o apartamento já existir e houver mudança de dono, os dados antigos serão salvos na CAIXA PRETA de Auditoria para resguardo legal."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCELAR")), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white), icon: const Icon(Icons.folder_open), label: const Text("SELECIONAR ARQUIVO"), onPressed: () { Navigator.pop(c); _importarPlanilhaCsv(); })])); }, icon: const Icon(Icons.upload_file), label: const Text("Importar Excel (CSV)")), const SizedBox(width: 15), FloatingActionButton.extended(heroTag: "btn_add", onPressed: () => _modalEditarProprietario(), icon: const Icon(Icons.add_home), label: const Text("Adicionar Unidade"))]),
      body: Column(children: [Container(padding: const EdgeInsets.all(15), color: Colors.blue.withValues(alpha:0.1), child: Row(children: [const Icon(Icons.security, color: Colors.blue, size: 30), const SizedBox(width: 10), Expanded(child: Text("Esta é a Base Legal do Condomínio. Os boletos do Asaas serão emitidos EXCLUSIVAMENTE para os CPFs e E-mails registrados aqui, ignorando o cadastro do App do Morador (Inquilino).", style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.bold)))])), Expanded(child: StreamBuilder<QuerySnapshot>(stream: FirebaseFirestore.instance.collection('unidades_base').where('sindico_vinculado', isEqualTo: widget.emailSindico).orderBy('bloco').orderBy('ap').snapshots(includeMetadataChanges: true), builder: (context, snap) { if (snap.hasError) return const Center(child: Text("Erro de permissão no Firebase. Crie o índice composto.")); if (!snap.hasData) return const Center(child: CircularProgressIndicator()); if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhuma unidade cadastrada. Clique em Adicionar Unidade.")); return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) { final doc = snap.data!.docs[i], data = doc.data() as Map<String, dynamic>; return Card(child: ListTile(leading: CircleAvatar(backgroundColor: colorScheme.primaryContainer, child: Icon(Icons.meeting_room, color: colorScheme.onPrimaryContainer)), title: Text("Bloco: ${data['bloco']} | AP: ${data['ap']}", style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Proprietário: ${data['nome_proprietario']}\nCPF/CNPJ: ${data['cpf_cnpj']} | E-mail: ${data['email']}"), trailing: IconButton(icon: Icon(Icons.edit, color: colorScheme.primary), tooltip: "Editar Dados (Gera Auditoria)", onPressed: () => _modalEditarProprietario(doc: doc)))); }); }))])
    );
  }
}

// [FIM DO BLOCO - DIGITE "CONTINUE" PARA GERAR A PRÓXIMA PARTE]
// ============================================================================
// RAIO-X FINANCEIRO (MASTER) - DASHBOARD E GRÁFICOS
// ============================================================================
class PainelFaturamentoSaaS extends StatefulWidget {
  const PainelFaturamentoSaaS({super.key});
  @override
  State<PainelFaturamentoSaaS> createState() => _PainelFaturamentoSaaSState();
}

class _PainelFaturamentoSaaSState extends State<PainelFaturamentoSaaS> {
  DateTime _mesFiltro = DateTime.now();
  final Map<String, List<Map<String, dynamic>>> _receitasCachePorMes = {};
  bool _carregando = false;

  @override
  void initState() { super.initState(); _carregarFaturamentoDoMes(_mesFiltro); }

  Future<void> _carregarFaturamentoDoMes(DateTime mes) async {
    final chaveMes = "${mes.month}_${mes.year}", cacheKey = 'fat_asaas_master_$chaveMes';
    final prefs = await SharedPreferences.getInstance(), hdDados = prefs.getString(cacheKey) ?? '';
    
    if (hdDados.isNotEmpty) {
      _receitasCachePorMes[chaveMes] = List<Map<String, dynamic>>.from(jsonDecode(hdDados));
      if (mounted) setState(() {});
    } else if (mounted) setState(() => _carregando = true);

    try {
      final inicioMes = DateTime(mes.year, mes.month, 1), fimMes = DateTime(mes.year, mes.month + 1, 0, 23, 59, 59);
      final snap = await FirebaseFirestore.instance.collection('receitas_saas').where('data_pagamento', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes)).where('data_pagamento', isLessThanOrEqualTo: Timestamp.fromDate(fimMes)).get();
      final dadosDoMes = snap.docs.map((doc) { final m = doc.data(); m['id'] = doc.id; if (m['data_pagamento'] is Timestamp) m['data_pagamento'] = (m['data_pagamento'] as Timestamp).toDate().toIso8601String(); return m; }).toList()..sort((a, b) => (b['data_pagamento'] ?? '').compareTo(a['data_pagamento'] ?? ''));
      _receitasCachePorMes[chaveMes] = dadosDoMes; await prefs.setString(cacheKey, jsonEncode(dadosDoMes));
      if (mounted) setState(() => _carregando = false);
    } catch (_) { if (mounted) setState(() => _carregando = false); }
  }

  Widget _cardKPI(String titulo, String valor, Color cor, IconData icone) => Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: cor.withValues(alpha:0.5), width: 2)), child: Padding(padding: const EdgeInsets.all(20.0), child: Row(children: [Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: cor.withValues(alpha:0.2), borderRadius: BorderRadius.circular(10)), child: Icon(icone, size: 35, color: cor)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 5), FittedBox(fit: BoxFit.scaleDown, child: Text(valor, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cor)))]))])));

  void _exportarExcel(List<Map<String, dynamic>> docs) {
    String csvData = "Data;Descricao_Pagamento;Email_Sindico;Forma_Pagamento;Valor\n";
    for(final d in docs) {
      final dataFormatada = d['data_pagamento'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(d['data_pagamento'])) : "";
      final nomeBase = d['nome_condominio'] ?? "Desconhecido", formaPgto = (d['forma_pagamento'] ?? "").toString().toUpperCase();
      final nomeLimpo = nomeBase.replaceAll(RegExp(r'split de pagamento autom[áa]tico', caseSensitive: false), '').replaceAll('-', '').trim();
      final tituloExibicao = (formaPgto.contains("SPLIT") || nomeBase.toLowerCase().contains("split")) ? "Taxa de faturamento de boleto, Administradora ${nomeLimpo.isEmpty ? "Parceiro/Administradora" : nomeLimpo}" : "Pagamento de mensalidade do sistema, Condomínio ${nomeLimpo.isEmpty ? "Parceiro/Administradora" : nomeLimpo}";
      csvData += "$dataFormatada;$tituloExibicao;${d['sindico_vinculado']};${d['forma_pagamento']};${d['valor']}\n";
    }
    showDialog(context: context, builder: (c) => AlertDialog(title: const Row(children: [Icon(Icons.table_chart, color: Colors.green), SizedBox(width: 10), Text("Exportação CSV")]), content: const Text("Os dados foram preparados para o Excel. Clique em copiar, abra uma planilha em branco e cole (Ctrl+V)."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("FECHAR")), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), icon: const Icon(Icons.copy), label: const Text("COPIAR DADOS"), onPressed: () { Clipboard.setData(ClipboardData(text: csvData)); Navigator.pop(c); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copiado! Cole no Excel."), backgroundColor: Colors.green)); })]));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme, chaveMes = "${_mesFiltro.month}_${_mesFiltro.year}", mesAnoFormat = DateFormat('MM/yyyy').format(_mesFiltro), docs = _receitasCachePorMes[chaveMes] ?? [];
    double faturamentoMesAtual = 0, maiorValorDia = 0; int transacoesMes = docs.length; final faturamentoPorDia = <int, double>{};
    for (final data in docs) {
      final valor = (data['valor'] ?? 0).toDouble(); faturamentoMesAtual += valor;
      if (data['data_pagamento'] != null) { final dia = DateTime.parse(data['data_pagamento']).day; faturamentoPorDia[dia] = (faturamentoPorDia[dia] ?? 0) + valor; }
    }
    final barGroups = List.generate(31, (i) { final v = faturamentoPorDia[i + 1] ?? 0; if (v > maiorValorDia) maiorValorDia = v; return BarChartGroupData(x: i + 1, barRods: [BarChartRodData(toY: v, color: v > 0 ? Colors.green : colorScheme.surfaceContainerHighest, width: 12, borderRadius: BorderRadius.circular(4))]); });

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 800;
      final painelGrafico = Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: Padding(padding: const EdgeInsets.all(20.0), child: _carregando ? const Center(child: CircularProgressIndicator()) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Receita Diária", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 30), Expanded(child: BarChart(BarChartData(alignment: BarChartAlignment.spaceAround, maxY: maiorValorDia > 0 ? maiorValorDia * 1.2 : 100, barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipItem: (group, _, rod, __) => BarTooltipItem("Dia ${group.x}\nR\$ ${rod.toY.toStringAsFixed(2)}", const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))), titlesData: FlTitlesData(show: true, bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => (v % 5 == 0 || v == 1 || v == 31) ? Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)) : const SizedBox.shrink())), leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: isMobile ? 30 : 40, getTitlesWidget: (v, _) => v == 0 ? const SizedBox.shrink() : Text("R\$${v.toInt()}", style: const TextStyle(fontSize: 10, color: Colors.grey)))), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))), gridData: const FlGridData(show: false), borderData: FlBorderData(show: false), barGroups: barGroups)))])));
      final painelLista = Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: Padding(padding: const EdgeInsets.all(16.0), child: _carregando ? const Center(child: CircularProgressIndicator()) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Últimos Pagamentos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)), const Divider(), Expanded(child: docs.isEmpty ? const Center(child: Text("Nenhuma transação no período.", style: TextStyle(color: Colors.grey))) : ListView.builder(itemCount: docs.length, itemBuilder: (ctx, i) { final data = docs[i], dataStr = data['data_pagamento'] != null ? DateFormat('dd/MM HH:mm').format(DateTime.parse(data['data_pagamento'])) : "N/D", nomeBase = data['nome_condominio'] ?? "Desconhecido", formaPgto = (data['forma_pagamento'] ?? "").toString().toUpperCase(); final nomeLimpo = nomeBase.replaceAll(RegExp(r'split de pagamento autom[áa]tico', caseSensitive: false), '').replaceAll('-', '').trim(); final tituloExibicao = (formaPgto.contains("SPLIT") || nomeBase.toLowerCase().contains("split")) ? "Taxa de faturamento de boleto, Administradora ${nomeLimpo.isEmpty ? "Parceiro/Administradora" : nomeLimpo}" : "Pagamento de mensalidade do sistema, Condomínio ${nomeLimpo.isEmpty ? "Parceiro/Administradora" : nomeLimpo}"; return ListTile(contentPadding: EdgeInsets.zero, leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white, size: 16)), title: Text(tituloExibicao, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Text("$dataStr\nVia: ${data['forma_pagamento']}", style: const TextStyle(fontSize: 11)), trailing: Text("R\$ ${(data['valor'] ?? 0).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14))); }))])));

      return Padding(
        padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Faturamento Asaas", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text("Dashboard de Receitas (Master)", style: TextStyle(color: colorScheme.onSurfaceVariant))])), Container(padding: const EdgeInsets.symmetric(horizontal: 5), decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.arrow_back_ios, size: 16), onPressed: () { setState(() => _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month - 1, 1)); _carregarFaturamentoDoMes(_mesFiltro); }), Text(mesAnoFormat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), IconButton(icon: const Icon(Icons.arrow_forward_ios, size: 16), onPressed: () { setState(() => _mesFiltro = DateTime(_mesFiltro.year, _mesFiltro.month + 1, 1)); _carregarFaturamentoDoMes(_mesFiltro); })]))]), const SizedBox(height: 20),
          isMobile ? Column(children: [_cardKPI("Faturamento do Mês", "R\$ ${faturamentoMesAtual.toStringAsFixed(2)}", Colors.green, Icons.trending_up), const SizedBox(height: 10), _cardKPI("Transações no Mês", "$transacoesMes pgto(s)", colorScheme.primary, Icons.receipt_long), const SizedBox(height: 10), SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: colorScheme.onSecondary, padding: const EdgeInsets.symmetric(vertical: 20)), icon: const Icon(Icons.table_chart, size: 24), label: const Text("EXPORTAR EXCEL", style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () => _exportarExcel(docs)))]) : Row(children: [Expanded(child: _cardKPI("Faturamento do Mês", "R\$ ${faturamentoMesAtual.toStringAsFixed(2)}", Colors.green, Icons.trending_up)), const SizedBox(width: 15), Expanded(child: _cardKPI("Transações no Mês", "$transacoesMes pgto(s)", colorScheme.primary, Icons.receipt_long)), const SizedBox(width: 15), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: colorScheme.onSecondary, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 35)), icon: const Icon(Icons.table_chart, size: 30), label: const Text("EXPORTAR EXCEL\n(CSV)", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () => _exportarExcel(docs))]), const SizedBox(height: 30),
          Expanded(child: isMobile ? SingleChildScrollView(child: Column(children: [SizedBox(height: 300, child: painelGrafico), const SizedBox(height: 15), SizedBox(height: 400, child: painelLista)])) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: painelGrafico), const SizedBox(width: 20), Expanded(flex: 1, child: painelLista)]))
        ]),
      );
    });
  }
}

// ============================================================================
// TELA DE CARREGAMENTO MINIMALISTA
// ============================================================================
class TelaCarregamentoAnimado extends StatefulWidget {
  final Widget? proximaTela;
  const TelaCarregamentoAnimado({super.key, this.proximaTela});
  @override
  State<TelaCarregamentoAnimado> createState() => _TelaCarregamentoAnimadoState();
}

class _TelaCarregamentoAnimadoState extends State<TelaCarregamentoAnimado> with SingleTickerProviderStateMixin {
  late AnimationController _controller; bool _mostrarConteudo = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    if (widget.proximaTela != null) {
      Future.delayed(const Duration(milliseconds: 500), () { if (mounted) setState(() => _mostrarConteudo = false); });
      Future.delayed(const Duration(milliseconds: 800), () { if (mounted) Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (context, animation, secondaryAnimation) => widget.proximaTela!, transitionsBuilder: (context, a, secondaryAnimation, c) => FadeTransition(opacity: a, child: c), transitionDuration: const Duration(milliseconds: 500))); });
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: themeNotifier.isNeonTheme ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor, 
    body: Stack(children: [
      if (themeNotifier.isNeonTheme) const Positioned.fill(child: GridBackground()),
      Center(child: AnimatedOpacity(opacity: _mostrarConteudo ? 1.0 : 0.0, duration: const Duration(milliseconds: 300), child: AnimatedBuilder(animation: _controller, builder: (context, child) => Text("INITIALIZING${List.generate((_controller.value * 3).floor() % 4, (_) => ".").join()}", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: themeNotifier.isNeonTheme ? Colors.white : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, letterSpacing: 4)))))
    ]),
  );
}

// ============================================================================
// COMPONENTE: CARTÃO DE TUTORIAL PREMIUM (User Onboarding)
// ============================================================================
class CardTutorial extends StatelessWidget {
  final TutorialCoachMarkController controller;
  final String titulo, texto; final IconData icone;
  const CardTutorial({super.key, required this.controller, required this.titulo, required this.texto, this.icone = Icons.info_outline});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: colorScheme.primary, width: 2), boxShadow: [BoxShadow(color: colorScheme.primary.withValues(alpha:0.5), blurRadius: 20)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Icon(icone, color: colorScheme.primary, size: 30), const SizedBox(width: 10), Expanded(child: Text(titulo, style: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)))]), const SizedBox(height: 10),
        Text(texto, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)), const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [TextButton(onPressed: () => controller.skip(), child: const Text("PULAR TUDO", style: TextStyle(color: Colors.grey))), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () => controller.next(), child: const Text("ENTENDI, PRÓXIMO ➔"))])
      ]),
    );
  }
}

// ============================================================================
// PARTE 11 - ANOTAÇÕES DA PORTARIA (TEXTO E FOTO COM FAXINA MENSAL)
// ============================================================================
class TelaAnotacoesPortaria extends StatefulWidget {
  final String emailSindico;
  const TelaAnotacoesPortaria({super.key, required this.emailSindico});
  @override
  State<TelaAnotacoesPortaria> createState() => _TelaAnotacoesPortariaState();
}

class _TelaAnotacoesPortariaState extends State<TelaAnotacoesPortaria> with WidgetsBindingObserver {
  String busca = ""; late Stream<QuerySnapshot> _ativasStream, _historicoStream; final ImagePicker _picker = ImagePicker();

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); _initStreams(); _realizarFaxinaSilenciosa(); }
  void _initStreams() { _ativasStream = FirebaseFirestore.instance.collection('anotacoes_portaria').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('status', isEqualTo: 'ativo').snapshots(); _historicoStream = FirebaseFirestore.instance.collection('anotacoes_portaria').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('status', isEqualTo: 'resolvido').snapshots(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) { if (state == AppLifecycleState.resumed) FirebaseAuth.instance.currentUser?.getIdToken(true); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  Future<void> _realizarFaxinaSilenciosa() async {
    try {
      final mesAtual = DateFormat('MM_yyyy').format(DateTime.now()), docSindico = await FirebaseFirestore.instance.collection('usuarios').doc(widget.emailSindico).get();
      if (docSindico.exists && docSindico.data()?['ultima_faxina_recados'] != mesAtual) {
        final snapVelhos = await FirebaseFirestore.instance.collection('anotacoes_portaria').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('status', isEqualTo: 'resolvido').where('data_resolucao', isLessThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 30)))).get();
        if (snapVelhos.docs.isNotEmpty) { for (var doc in snapVelhos.docs) { if (doc.data()['foto_path']?.toString().isNotEmpty == true) try { await FirebaseStorage.instance.ref().child(doc.data()['foto_path']).delete(); } catch(_) {} await doc.reference.delete(); } }
        await docSindico.reference.update({'ultima_faxina_recados': mesAtual});
      }
    } catch (_) {}
  }

  void _novaAnotacao() {
    String bloco = "", ap = "", texto = ""; Uint8List? fotoBytesLocal; bool processando = false;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Row(children: [Icon(Icons.push_pin, color: colorScheme.secondary), const SizedBox(width: 10), const Text("Criar Anotação")]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: TextField(onChanged: (v) => bloco = v.trim().toUpperCase(), decoration: const InputDecoration(labelText: "Bloco *", border: OutlineInputBorder()), inputFormatters: [UpperCaseTextFormatter()])), const SizedBox(width: 10), Expanded(child: TextField(onChanged: (v) => ap = v.trim(), decoration: const InputDecoration(labelText: "AP *", border: OutlineInputBorder())))]), const SizedBox(height: 15),
          TextField(onChanged: (v) => texto = v, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: "Texto Rápido (Opcional)", border: OutlineInputBorder())), const SizedBox(height: 15),
          InkWell(onTap: processando ? null : () async { try { Uint8List? bytes; if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) bytes = await showDialog<Uint8List>(context: context, barrierDismissible: false, builder: (ctxCam) => const DialogCapturaCamera(titulo: "Fotografar Papel / Anotação")); else { final photo = await _picker.pickImage(source: ImageSource.camera, maxWidth: 800, imageQuality: 70); if (photo != null) bytes = await photo.readAsBytes(); } if (bytes != null) setStateSB(() => fotoBytesLocal = bytes); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro ao abrir câmera"))); } }, child: Container(height: 120, width: double.infinity, decoration: BoxDecoration(color: fotoBytesLocal != null ? Colors.green.withValues(alpha:0.1) : colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10), border: Border.all(color: fotoBytesLocal != null ? Colors.green : colorScheme.outlineVariant), image: fotoBytesLocal != null ? DecorationImage(image: MemoryImage(fotoBytesLocal!), fit: BoxFit.cover) : null), child: fotoBytesLocal == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, size: 40, color: colorScheme.onSurfaceVariant), const SizedBox(height: 5), Text("Fotografar Papel Escrito", style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold))]) : null)),
          if (fotoBytesLocal != null) Center(child: TextButton.icon(icon: const Icon(Icons.refresh, size: 14), label: const Text("Tirar foto novamente"), onPressed: processando ? null : () => setStateSB(() => fotoBytesLocal = null)))
        ])),
        actions: [
          if (!processando) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.secondary, foregroundColor: colorScheme.onSecondary), onPressed: processando ? null : () async {
            if (bloco.isEmpty || ap.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha Bloco e AP para conseguirmos buscar depois!"))); return; }
            if (texto.isEmpty && fotoBytesLocal == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Escreva algo ou tire foto do papel!"))); return; }
            setStateSB(() => processando = true);
            try {
              String fotoUrl = "", fotoPath = "";
              if (fotoBytesLocal != null) { fotoPath = "anotacoes_portaria/${widget.emailSindico}/${const Uuid().v4()}.jpg"; final ref = FirebaseStorage.instance.ref().child(fotoPath); await ref.putData(fotoBytesLocal!, SettableMetadata(contentType: 'image/jpeg')); fotoUrl = await ref.getDownloadURL(); }
              await FirebaseFirestore.instance.collection('anotacoes_portaria').add({'sindico_vinculado': widget.emailSindico, 'bloco': bloco, 'ap': ap, 'texto': texto, 'foto_url': fotoUrl, 'foto_path': fotoPath, 'status': 'ativo', 'criado_por': operadorLogado, 'data_criacao': FieldValue.serverTimestamp()});
              if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Anotação grudada no mural!"), backgroundColor: Colors.green)); }
            } catch (e) { setStateSB(() => processando = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); }
          }, child: processando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SALVAR ANOTAÇÃO"))
        ],
      );
    }));
  }

  void _mostrarFotoEmTelaCheia(String urlFoto) => showDialog(context: context, builder: (ctx) => Dialog(backgroundColor: Colors.transparent, child: Stack(alignment: Alignment.center, children: [InteractiveViewer(panEnabled: true, minScale: 0.5, maxScale: 4, child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: NetworkImage(urlFoto), fit: BoxFit.contain)))), Positioned(top: 10, right: 10, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 40), onPressed: () => Navigator.pop(ctx)))])));
  void _marcarComoUsado(DocumentReference ref) => showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Finalizar Anotação?"), content: const Text("Ela será guardada no histórico. No dia 1º de cada mês, as anotações usadas há mais de 30 dias serão apagadas automaticamente."), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("NÃO, DEIXAR AÍ")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: () async { await ref.update({'status': 'resolvido', 'resolvido_por': operadorLogado, 'data_resolucao': FieldValue.serverTimestamp()}); if (mounted) Navigator.pop(ctx); }, child: const Text("SIM, FINALIZAR"))]));

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(length: 2, child: Scaffold(
      appBar: MediaQuery.of(context).size.width < 800 ? AppBar(leading: IconButton(icon: const Icon(Icons.menu), onPressed: () => Scaffold.of(context).openDrawer()), title: const Text("Anotações da Portaria"), backgroundColor: Colors.transparent, elevation: 0) : null,
      floatingActionButton: FloatingActionButton.extended(key: keyTutAnotacaoNova, onPressed: _novaAnotacao, icon: const Icon(Icons.edit_note), label: const Text("Nova Anotação", style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [Icon(Icons.push_pin, size: 40, color: colorScheme.secondary), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const FittedBox(fit: BoxFit.scaleDown, child: Text("Mural de Anotações", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))), FittedBox(fit: BoxFit.scaleDown, child: Text("Tire fotos de recados ou anote palavras-chave para o seu turno.", style: TextStyle(color: colorScheme.onSurfaceVariant)))]))])),
        TabBar(labelColor: colorScheme.primary, unselectedLabelColor: colorScheme.onSurfaceVariant, tabs: const [Tab(icon: Icon(Icons.note_alt), text: "Ativas no Balcão"), Tab(icon: Icon(Icons.history), text: "Histórico")]),
        Padding(padding: const EdgeInsets.all(16.0), child: TextField(onChanged: (v) => setState(() => busca = v.toLowerCase()), decoration: const InputDecoration(labelText: "Buscar por Bloco-AP (Ex: 10-12, B-102) ou texto...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
        Expanded(child: TabBarView(children: [_buildGridAnotacoes(_ativasStream, true), _buildGridAnotacoes(_historicoStream, false)]))
      ]),
    ));
  }

  Widget _buildGridAnotacoes(Stream<QuerySnapshot> stream, bool isAtiva) => StreamBuilder<QuerySnapshot>(stream: stream, builder: (context, snap) {
    if (snap.hasError) return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: SelectableText("O Firebase pediu um Índice. Copie este erro e cole no navegador:\n\n${snap.error}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center)));
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final docs = snap.data!.docs.where((d) { final data = d.data() as Map<String, dynamic>, b = (data['bloco'] ?? '').toString().toLowerCase(), a = (data['ap'] ?? '').toString().toLowerCase(), r = (data['texto'] ?? '').toString().toLowerCase(); return b.contains(busca) || a.contains(busca) || r.contains(busca) || "$b-$a".contains(busca.replaceAll(' ', '')); }).toList()..sort((a, b) => ((b.data() as Map)['data_criacao'] ?? Timestamp.now()).compareTo((a.data() as Map)['data_criacao'] ?? Timestamp.now()));
    if (docs.isEmpty) return Center(child: Text(isAtiva ? "Mural limpo! Nenhuma anotação pendente." : "Nenhum histórico encontrado."));

    return GridView.builder(padding: const EdgeInsets.all(16), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 280, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.9), itemCount: docs.length, itemBuilder: (context, index) {
      final doc = docs[index], data = doc.data() as Map<String, dynamic>, dataStr = data['data_criacao'] != null ? DateFormat('dd/MM HH:mm').format((data['data_criacao'] as Timestamp).toDate()) : "Agora", temFoto = data['foto_url']?.toString().isNotEmpty == true, texto = data['texto'] ?? '';
      return Card(elevation: isAtiva ? 5 : 1, color: isAtiva ? const Color(0xFFFFF9C4) : Theme.of(context).colorScheme.surfaceContainerHighest, shape: RoundedRectangleBorder(borderRadius: const BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(15), bottomLeft: Radius.circular(5), bottomRight: Radius.circular(15)), side: BorderSide(color: isAtiva ? Colors.orange.withValues(alpha:0.5) : Colors.transparent)), child: Stack(children: [
        Padding(padding: const EdgeInsets.all(12.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [FittedBox(fit: BoxFit.scaleDown, child: Text("B: ${data['bloco']} | AP: ${data['ap']}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isAtiva ? Colors.black87 : Colors.grey))), const Divider(color: Colors.black12, height: 10), if (texto.isNotEmpty) Expanded(flex: temFoto ? 1 : 3, child: SingleChildScrollView(child: Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(texto, style: TextStyle(color: isAtiva ? Colors.black : Colors.grey, fontWeight: FontWeight.w500))))), if (temFoto) Expanded(flex: 2, child: InkWell(onTap: () => _mostrarFotoEmTelaCheia(data['foto_url']), child: Container(width: double.infinity, decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(8), image: DecorationImage(image: NetworkImage(data['foto_url']), fit: BoxFit.cover)), child: const Center(child: Icon(Icons.zoom_in, color: Colors.white54, size: 40))))) else if (texto.isEmpty) const Spacer(), const SizedBox(height: 10), Text("Por: ${data['criado_por']}\nEm: $dataStr", style: TextStyle(fontSize: 10, color: isAtiva ? Colors.black54 : Colors.grey))])),
        if (isAtiva) Positioned(top: 5, right: 5, child: Icon(Icons.push_pin, color: Colors.red.withValues(alpha:0.8), size: 20)),
        if (isAtiva) Positioned(bottom: 0, right: 0, child: IconButton(icon: const Icon(Icons.check_circle, color: Colors.green, size: 35), tooltip: "Finalizar Anotação", onPressed: () => _marcarComoUsado(doc.reference))),
        if (!isAtiva) Positioned(top: 5, right: 5, child: IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), tooltip: "Apagar Histórico", onPressed: () { if (temFoto) FirebaseStorage.instance.ref().child(data['foto_path']).delete().then((_) {}, onError: (_) {}); doc.reference.delete(); }))
      ]));
    });
  });
}

// ============================================================================
// PARTE 12 - TELA INSTITUCIONAL (SOBRE A LOGIC HOME)
// ============================================================================
class TelaSobreSistema extends StatelessWidget {
  const TelaSobreSistema({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: SingleChildScrollView(child: Padding(padding: EdgeInsets.all(20.0), child: CardSobreLogicHome(isDialog: false))));
}

class CardSobreLogicHome extends StatelessWidget {
  final bool isDialog;
  const CardSobreLogicHome({super.key, required this.isDialog});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme, isDark = Theme.of(context).brightness == Brightness.dark;
    final conteudo = Container(
      width: 500, padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: isDark ? const Color(0xFF0D111C).withValues(alpha:0.9) : colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: colorScheme.primary.withValues(alpha:0.5), width: 2), boxShadow: isDialog ? [BoxShadow(color: colorScheme.primary.withValues(alpha:0.2), blurRadius: 30, spreadRadius: 5)] : []),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const LogoLogicHome(size: 80), const SizedBox(height: 20), Text("A REVOLUÇÃO DA PORTARIA", style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 12)), const SizedBox(height: 15), Text("", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant, height: 1.5)), const Divider(height: 40),
        _itemPilar(Icons.memory, "Arquitetura IoT & Edge Computing", "Portões e catracas acionados em milissegundos, integrando hardware e software.", colorScheme), const SizedBox(height: 15), _itemPilar(Icons.document_scanner, "Inteligência Artificial (OCR)", "Leitura automatizada de documentos para um controle de acesso rápido e seguro.", colorScheme), const SizedBox(height: 15), _itemPilar(Icons.cloud_sync, "Vídeo Cloudflare Zero Trust", "As câmeras do condomínio direto no 4G, protegidas por criptografia avançada.", colorScheme), const SizedBox(height: 30),
        Text("Versão do Sistema: SaaS Enterprise v2.0", style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha:0.5), fontSize: 10)),
        if (isDialog) ...[const SizedBox(height: 15), LogicNeonButton(fullWidth: true, corBase: colorScheme.primary, corBrilho: colorScheme.primary, onPressed: () => Navigator.pop(context), child: const Text("FECHAR", style: TextStyle(color: Colors.white)))]
      ]),
    );
    return isDialog ? Dialog(backgroundColor: Colors.transparent, insetPadding: const EdgeInsets.all(20), child: SingleChildScrollView(child: conteudo)) : conteudo;
  }

  Widget _itemPilar(IconData icone, String titulo, String descricao, ColorScheme cores) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: cores.primaryContainer, borderRadius: BorderRadius.circular(10)), child: Icon(icone, color: cores.primary, size: 24)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: cores.onSurface, fontSize: 14)), const SizedBox(height: 4), Text(descricao, style: TextStyle(color: cores.onSurfaceVariant, fontSize: 12, height: 1.3))]))]);
}

// ============================================================================
// PARTE 13 - SISTEMA DE RONDA VIRTUAL (PORTARIA E SÍNDICO)
// ============================================================================
class BotaoRondaPulsante extends StatefulWidget {
  final VoidCallback onPressed; final bool emAlerta;
  const BotaoRondaPulsante({super.key, required this.onPressed, this.emAlerta = false});
  @override
  State<BotaoRondaPulsante> createState() => _BotaoRondaPulsanteState();
}

class _BotaoRondaPulsanteState extends State<BotaoRondaPulsante> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  @override
  void initState() { super.initState(); _animController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(); }
  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final corPrincipal = widget.emAlerta ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return GestureDetector(onTap: widget.onPressed, child: AnimatedBuilder(animation: _animController, builder: (context, child) => Stack(alignment: Alignment.center, children: [Opacity(opacity: 1.0 - _animController.value, child: Transform.scale(scale: 1.0 + (_animController.value * 1.5), child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: corPrincipal.withValues(alpha:0.8), width: 4))))), Opacity(opacity: 1.0 - ((_animController.value + 0.5) % 1.0), child: Transform.scale(scale: 1.0 + (((_animController.value + 0.5) % 1.0) * 1.5), child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: corPrincipal.withValues(alpha:0.4), width: 2))))), Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: corPrincipal, boxShadow: [BoxShadow(color: corPrincipal.withValues(alpha:0.6), blurRadius: 20, spreadRadius: 5)]), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.fingerprint, size: 50, color: Colors.white), SizedBox(height: 5), Text("REGISTRAR\nRONDA", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]))])));
  }
}

class TelaRondaPortaria extends StatefulWidget {
  final String emailSindico;
  const TelaRondaPortaria({super.key, required this.emailSindico});
  @override
  State<TelaRondaPortaria> createState() => _TelaRondaPortariaState();
}

class _TelaRondaPortariaState extends State<TelaRondaPortaria> {
  Timer? _motorRondaTimer; Player? _audioPlayer; bool _emAtraso = false, _processandoClique = false, _alarmeTocouNestaRonda = false;
  String _mensagemStatus = "Aguardando próximo horário de ronda..."; Map<String, dynamic>? _rondaAtiva; final Set<String> _rondasPerdidasProcessadas = {};

  @override
  void initState() { super.initState(); _audioPlayer = Player(); _iniciarMotorDeRonda(); }
  @override
  void dispose() { _motorRondaTimer?.cancel(); _audioPlayer?.dispose(); super.dispose(); }

  DateTime _calcularDataAlvo(String horarioStr, DateTime agora) {
    final h = int.parse(horarioStr.split(':')[0]), m = int.parse(horarioStr.split(':')[1]), alvoHoje = DateTime(agora.year, agora.month, agora.day, h, m);
    if (h >= 20 && agora.hour < 12) return alvoHoje.subtract(const Duration(days: 1));
    if (h < 12 && agora.hour >= 20) return alvoHoje.add(const Duration(days: 1));
    return alvoHoje;
  }

  void _iniciarMotorDeRonda() {
    _motorRondaTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted) return;
      final snap = await FirebaseFirestore.instance.collection('configuracoes_ronda').where('sindico_vinculado', isEqualTo: widget.emailSindico).get(), agora = DateTime.now();
      bool encontrouRondaAtiva = false, tocandoAlarmeLocal = false;

      for (var doc in snap.docs) {
        final config = doc.data(), horario = config['horario'], dataAlvo = _calcularDataAlvo(horario, agora), inicioTolerancia = dataAlvo.subtract(Duration(minutes: config['tolerancia_minutos'])), fimTolerancia = dataAlvo.add(Duration(minutes: config['tolerancia_minutos'])), fimAdvertencia = fimTolerancia.add(Duration(minutes: config['tempo_advertencia_minutos'])), idUnicoRondaDiaria = "${doc.id}_${dataAlvo.year}-${dataAlvo.month}-${dataAlvo.day}";
        if ((await FirebaseFirestore.instance.collection('registros_ronda').where('sindico_vinculado', isEqualTo: widget.emailSindico).where('id_unico_ronda_diaria', isEqualTo: idUnicoRondaDiaria).limit(1).get()).docs.isNotEmpty) continue;

        if (agora.isAfter(inicioTolerancia) && agora.isBefore(fimTolerancia)) {
          encontrouRondaAtiva = true; _rondaAtiva = config..['id_unico_ronda_diaria'] = idUnicoRondaDiaria; _alarmeTocouNestaRonda = false;
          if (mounted) setState(() { _emAtraso = false; _mensagemStatus = "Ronda das $horario liberada! Clique para registrar."; }); break;
        } else if (agora.isAfter(fimTolerancia) && agora.isBefore(fimAdvertencia)) {
          encontrouRondaAtiva = true; tocandoAlarmeLocal = true; _rondaAtiva = config..['id_unico_ronda_diaria'] = idUnicoRondaDiaria;
          if (!_alarmeTocouNestaRonda) { _audioPlayer!.open(Media((DateTime.now().hour >= 5 && DateTime.now().hour < 12) ? 'asset:///assets/alerta_ronda_manha.mp3' : 'asset:///assets/alerta_ronda_noite.mp3'), play: true); _alarmeTocouNestaRonda = true; }
          if (mounted) setState(() { _emAtraso = true; _mensagemStatus = "⚠️ ATENÇÃO: Você está atrasado para a ronda das $horario! Faltam ${fimAdvertencia.difference(agora).inMinutes} min para notificar o síndico."; }); break;
        } else if (agora.isAfter(fimAdvertencia) && !_rondasPerdidasProcessadas.contains(idUnicoRondaDiaria)) {
          _rondasPerdidasProcessadas.add(idUnicoRondaDiaria);
          await FirebaseFirestore.instance.collection('registros_ronda').add({'sindico_vinculado': widget.emailSindico, 'horario_referencia': horario, 'id_unico_ronda_diaria': idUnicoRondaDiaria, 'data_registro': FieldValue.serverTimestamp(), 'operador': operadorLogado, 'status': 'perdida'});
          await FirebaseFirestore.instance.collection('notificacoes').add({'sindico_vinculado': widget.emailSindico, 'para': widget.emailSindico, 'nome_destino': 'Síndico', 'titulo': '🚨 RONDA NÃO REALIZADA!', 'mensagem': 'O porteiro $operadorLogado não registrou a ronda programada para as $horario.', 'data': FieldValue.serverTimestamp(), 'remetente': 'Sistema de Ronda'});
          await registrarAuditoria(widget.emailSindico, "Ronda Perdida", "Segurança", "Porteiro perdeu a ronda das $horario.");
        }
      }

      if (!encontrouRondaAtiva) { _rondaAtiva = null; if (_audioPlayer!.state.playing) _audioPlayer!.stop(); if (mounted) setState(() { _emAtraso = false; _mensagemStatus = "Aguardando próximo horário de ronda..."; }); }
      else if (!tocandoAlarmeLocal && _audioPlayer!.state.playing) _audioPlayer!.stop();
    });
  }


  void _registrarRonda() async {
    if (_rondaAtiva == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Não há nenhuma ronda programada para este exato momento."))); return; }
    if (_processandoClique) return; setState(() => _processandoClique = true);
    try {
      if (_audioPlayer!.state.playing) _audioPlayer!.stop();
      await FirebaseFirestore.instance.collection('registros_ronda').add({'sindico_vinculado': widget.emailSindico, 'horario_referencia': _rondaAtiva!['horario'], 'id_unico_ronda_diaria': _rondaAtiva!['id_unico_ronda_diaria'], 'data_registro': FieldValue.serverTimestamp(), 'operador': operadorLogado, 'status': _emAtraso ? 'com_atraso' : 'no_prazo'});
      await registrarAuditoria(widget.emailSindico, "Ronda Realizada", "Segurança", "Ronda das ${_rondaAtiva!['horario']} registrada por $operadorLogado.");
      if (mounted) { setState(() { _rondaAtiva = null; _emAtraso = false; _processandoClique = false; _mensagemStatus = "Ronda registrada com sucesso!"; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Ronda salva no sistema!"), backgroundColor: Colors.green)); }
    } catch (e) { if (mounted) { setState(() => _processandoClique = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(TratamentoDeErros.traduzir(e)), backgroundColor: Colors.red)); } }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_moon, size: 80, color: colorScheme.secondary), const SizedBox(height: 20), const Text("Controle de Ronda Virtual", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 10), Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _emAtraso ? colorScheme.errorContainer : colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10), border: Border.all(color: _emAtraso ? colorScheme.error : colorScheme.primary)), child: Text(_mensagemStatus, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _emAtraso ? colorScheme.onErrorContainer : colorScheme.onSurfaceVariant))), const SizedBox(height: 40), BotaoRondaPulsante(key: keyTutRondaBotao, emAlerta: _emAtraso, onPressed: _registrarRonda)])),
    );
  }
}

class TelaGestaoRondas extends StatefulWidget {
  final String emailSindico;
  const TelaGestaoRondas({super.key, required this.emailSindico});
  @override
  State<TelaGestaoRondas> createState() => _TelaGestaoRondasState();
}

class _TelaGestaoRondasState extends State<TelaGestaoRondas> {
  late Stream<QuerySnapshot> _configStream, _logsStream;
  DateTime? _dataFiltroInicio, _dataFiltroFim; String _buscaOperador = ""; int _limiteLogsRonda = 30;

  @override
  void initState() { super.initState(); _configStream = FirebaseFirestore.instance.collection('configuracoes_ronda').where('sindico_vinculado', isEqualTo: widget.emailSindico).snapshots(); _logsStream = FirebaseFirestore.instance.collection('registros_ronda').where('sindico_vinculado', isEqualTo: widget.emailSindico).orderBy('data_registro', descending: true).limit(_limiteLogsRonda).snapshots(); }

  Future<void> _selecionarDataFiltroLogs(BuildContext context) async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now(), builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme), child: child!));
    if (picked != null) setState(() { _dataFiltroInicio = picked.start; _dataFiltroFim = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59); });
  }

  void _novaConfigRonda() {
    TimeOfDay? horarioSelecionado; final tolCtrl = TextEditingController(text: "5"), advCtrl = TextEditingController(text: "5");
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
      final colorScheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const Text("Nova Ronda Programada"),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Atenção: Rondas só podem ser criadas entre 20:00 e 07:00.", style: TextStyle(color: Colors.orange, fontSize: 12)), const SizedBox(height: 15), InkWell(onTap: () async { final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 22, minute: 0)); if (picked != null) { if (picked.hour >= 7 && picked.hour < 20) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Horário inválido. Escolha entre 20h e 07h."), backgroundColor: Colors.red)); return; } setStateSB(() => horarioSelecionado = picked); } }, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: colorScheme.outline), borderRadius: BorderRadius.circular(5)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(horarioSelecionado == null ? "Selecionar Horário Alvo" : "${horarioSelecionado!.hour.toString().padLeft(2, '0')}:${horarioSelecionado!.minute.toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const Icon(Icons.access_time)]))), const SizedBox(height: 15), TextField(controller: tolCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Tolerância (Minutos para + ou para -)", helperText: "Tempo que ele pode clicar antes ou depois.")), const SizedBox(height: 10), TextField(controller: advCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Tempo de Advertência (Minutos)", helperText: "Tempo que o alarme toca antes de alertar você."))]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), onPressed: () async {
          if (horarioSelecionado == null || tolCtrl.text.isEmpty || advCtrl.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Preencha todos os campos!"))); return; }
          await FirebaseFirestore.instance.collection('configuracoes_ronda').add({'sindico_vinculado': widget.emailSindico, 'horario': "${horarioSelecionado!.hour.toString().padLeft(2, '0')}:${horarioSelecionado!.minute.toString().padLeft(2, '0')}", 'tolerancia_minutos': int.parse(tolCtrl.text), 'tempo_advertencia_minutos': int.parse(advCtrl.text)});
          if (mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ronda configurada com sucesso!"))); }
        }, child: const Text("SALVAR"))]
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(length: 2, child: Scaffold(
      floatingActionButton: FloatingActionButton.extended(key: keyTutGestaoRondaNova, onPressed: _novaConfigRonda, icon: const Icon(Icons.add_alarm), label: const Text("Programar Ronda")),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [Icon(Icons.shield_moon, size: 40, color: colorScheme.secondary), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Gestão de Rondas", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Text("Monitore a atividade da portaria durante a madrugada.", style: TextStyle(color: colorScheme.onSurfaceVariant))]))])),
        TabBar(labelColor: colorScheme.primary, unselectedLabelColor: colorScheme.onSurfaceVariant, tabs: const [Tab(icon: Icon(Icons.settings), text: "Rondas Programadas"), Tab(icon: Icon(Icons.history), text: "Relatório de Execução")]),
        Expanded(child: TabBarView(children: [
          StreamBuilder<QuerySnapshot>(stream: _configStream, builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhuma ronda configurada."));
            return ListView.builder(padding: const EdgeInsets.all(16), itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) { final doc = snap.data!.docs[i], data = doc.data() as Map<String, dynamic>; return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.access_time)), title: Text("Ronda das ${data['horario']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), subtitle: Text("Tolerância: ±${data['tolerancia_minutos']} min | Advertência: ${data['tempo_advertencia_minutos']} min"), trailing: IconButton(icon: Icon(Icons.delete, color: colorScheme.error), onPressed: () => doc.reference.delete()))); });
          }),
          Column(children: [
            Padding(key: keyTutGestaoRondaFiltro, padding: const EdgeInsets.all(16), child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [SizedBox(width: 300, child: TextField(onChanged: (v) => setState(() => _buscaOperador = v.toLowerCase()), decoration: const InputDecoration(labelText: "Filtrar por Porteiro", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))), FittedBox(fit: BoxFit.scaleDown, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: _dataFiltroInicio != null ? colorScheme.primary : colorScheme.surfaceContainerHighest, foregroundColor: _dataFiltroInicio != null ? colorScheme.onPrimary : colorScheme.onSurfaceVariant, padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15)), icon: const Icon(Icons.calendar_month), label: Text(_dataFiltroInicio != null ? "${DateFormat('dd/MM').format(_dataFiltroInicio!)} - ${DateFormat('dd/MM').format(_dataFiltroFim!)}" : "Filtrar Data"), onPressed: () => _selecionarDataFiltroLogs(context))), if (_dataFiltroInicio != null) IconButton(icon: Icon(Icons.clear, color: colorScheme.error), onPressed: () => setState(() { _dataFiltroInicio = null; _dataFiltroFim = null; }))])),
            Expanded(child: StreamBuilder<QuerySnapshot>(stream: _logsStream, builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final filtrados = snap.data!.docs.where((d) { final data = d.data() as Map<String, dynamic>; if (_dataFiltroInicio != null && data['data_registro'] != null) { final dt = (data['data_registro'] as Timestamp).toDate(); if (dt.isBefore(_dataFiltroInicio!) || dt.isAfter(_dataFiltroFim!)) return false; } if (_buscaOperador.isNotEmpty && !(data['operador'] ?? "").toString().toLowerCase().contains(_buscaOperador)) return false; return true; }).toList()..sort((a, b) => ((b.data() as Map)['data_registro'] ?? Timestamp.now()).compareTo((a.data() as Map)['data_registro'] ?? Timestamp.now()));
              if (filtrados.isEmpty) return const Center(child: Text("Nenhum registro encontrado para estes filtros."));
              return ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtrados.length + (_dataFiltroInicio == null && _buscaOperador.isEmpty ? 1 : 0), itemBuilder: (ctx, i) {
                if (_dataFiltroInicio == null && _buscaOperador.isEmpty && i == filtrados.length) return Padding(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20), child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(15)), icon: const Icon(Icons.history), label: Text("CARREGAR MAIS (Mostrando $_limiteLogsRonda registros)"), onPressed: () => setState(() { _limiteLogsRonda += 50; _logsStream = FirebaseFirestore.instance.collection('registros_ronda').where('sindico_vinculado', isEqualTo: widget.emailSindico).orderBy('data_registro', descending: true).limit(_limiteLogsRonda).snapshots(); })));
                final data = filtrados[i].data() as Map<String, dynamic>; String statusStr = "No Prazo", dataReg = data['data_registro'] != null ? DateFormat('dd/MM HH:mm').format((data['data_registro'] as Timestamp).toDate()) : ''; Color corStatus = Colors.green; IconData icone = Icons.check_circle;
                if (data['status'] == 'com_atraso') { statusStr = "Com Atraso (Após tolerância)"; corStatus = Colors.orange; icone = Icons.warning; } else if (data['status'] == 'perdida') { statusStr = "NÃO REALIZADA (Falta)"; corStatus = Colors.red; icone = Icons.cancel; }
                return Card(shape: RoundedRectangleBorder(side: BorderSide(color: corStatus.withValues(alpha:0.5)), borderRadius: BorderRadius.circular(8)), child: ListTile(leading: Icon(icone, color: corStatus, size: 35), title: Text("Alvo: ${data['horario_referencia']} | Operador: ${data['operador']}", style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Registrado em: $dataReg"), trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: corStatus.withValues(alpha:0.2), borderRadius: BorderRadius.circular(5)), child: Text(statusStr, style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 12)))));
              });
            }))
          ])
        ]))
      ])
    ));
  }
}

// ============================================================================
// PARTE 14 - ACESSO POR APROXIMAÇÃO (BLUETOOTH E NUVEM)
// ============================================================================
class RadarBluetooth {
  static Future<void> ligarRadar() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) return;
    if (await Permission.bluetoothScan.request().isGranted && await Permission.bluetoothConnect.request().isGranted && await Permission.locationWhenInUse.request().isGranted && await Permission.notification.request().isGranted) {
      await Permission.locationAlways.request();
      if (defaultTargetPlatform == TargetPlatform.android) await FlutterLocalNotificationsPlugin().resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(const AndroidNotificationChannel('radar_silencioso_v1', 'Radar Bluetooth (Acesso Automático)', description: 'Mantém a conexão com os portões ativa em segundo plano.', importance: Importance.min));
      final service = FlutterBackgroundService(); if (await service.isRunning()) return;
      await service.configure(androidConfiguration: AndroidConfiguration(onStart: _onStartBackground, autoStart: true, isForegroundMode: true, notificationChannelId: 'radar_silencioso_v1', initialNotificationTitle: 'Radar Logic Home', initialNotificationContent: 'Acesso automático ativo. (Você pode silenciar isso nas configurações do Android).', foregroundServiceNotificationId: 888), iosConfiguration: IosConfiguration(autoStart: true, onForeground: _onStartBackground, onBackground: _onIosBackground));
      await service.startService();
    }
  }

  static Future<void> desligarRadar() async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) return;
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('stopService');
      }
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async { WidgetsFlutterBinding.ensureInitialized(); DartPluginRegistrant.ensureInitialized(); return true; }

@pragma('vm:entry-point')
void _onStartBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized(); DartPluginRegistrant.ensureInitialized();
  service.on('stopService').listen((_) => service.stopSelf());
  final localNotif = FlutterLocalNotificationsPlugin();
  await localNotif.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/launcher_icon'), iOS: DarwinInitializationSettings()));
  if (defaultTargetPlatform == TargetPlatform.android) await localNotif.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(const AndroidNotificationChannel('canal_chegada_v1', 'Chegada no Portão', importance: Importance.max, playSound: true, enableVibration: true));
  
  bool notificouRecentemente = false;
  FlutterBluePlus.scanResults.listen((results) async {
    if (notificouRecentemente) return;
    if (results.any((r) => (r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName).contains("PORTAO") || r.advertisementData.serviceUuids.any((uuid) => uuid.toString().toLowerCase() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b"))) {
       try { if (jsonDecode((await SharedPreferences.getInstance()).getString('off_user_data') ?? '')['perfil'] != 'morador') return; } catch (_) { return; }
       notificouRecentemente = true;
       localNotif.show(999, '📍 Você chegou no Condomínio!', 'Toque aqui para abrir a garagem/portão.', const NotificationDetails(android: AndroidNotificationDetails('canal_chegada_v1', 'Chegada no Portão', importance: Importance.max, priority: Priority.max, color: Color(0xFF00E5FF), enableVibration: true, playSound: true), iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true)), payload: 'abrir_portao_aproximacao');
       Future.delayed(const Duration(minutes: 5), () => notificouRecentemente = false);
    }
  });
  Timer.periodic(const Duration(seconds: 30), (_) async { try { if (await FlutterBluePlus.adapterState.first == BluetoothAdapterState.on && await FlutterBluePlus.isScanning.first == false) await FlutterBluePlus.startScan(withServices: [Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b")], timeout: const Duration(seconds: 5), androidScanMode: AndroidScanMode.lowLatency); } catch (_) {} });
}

class TelaAberturaPorAproximacao extends StatefulWidget {
  final Map<String, dynamic> userData;
  const TelaAberturaPorAproximacao({super.key, required this.userData});
  @override
  State<TelaAberturaPorAproximacao> createState() => _TelaAberturaPorAproximacaoState();
}

class _TelaAberturaPorAproximacaoState extends State<TelaAberturaPorAproximacao> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController; bool _processandoLocal = false;

  @override
  void initState() { super.initState(); _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true); }
  @override
  void dispose() { _pulseController.dispose(); super.dispose(); }

  Future<String> _abrirViaBluetooth(String macApp, String rele) async {
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) return "ERR";
    try {
      if (defaultTargetPlatform == TargetPlatform.android) { final st = await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse].request(); if (st[Permission.bluetoothConnect]!.isPermanentlyDenied || st[Permission.bluetoothScan]!.isPermanentlyDenied) { openAppSettings(); return "ERR"; } }
      await Future.delayed(const Duration(milliseconds: 200));
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        if (defaultTargetPlatform == TargetPlatform.android) try { await FlutterBluePlus.turnOn(); } catch (_) {}
        try { await FlutterBluePlus.adapterState.where((s) => s == BluetoothAdapterState.on).first.timeout(const Duration(seconds: 5)); } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ative o Bluetooth para abrir o portão!"), backgroundColor: Colors.orange)); return "ERR"; }
      }
      try { await FlutterBluePlus.stopScan(); } catch(_) {} await Future.delayed(const Duration(milliseconds: 500));
      final completer = Completer<String>(); bool conectando = false;
      final sub = FlutterBluePlus.scanResults.listen((results) async {
        if (conectando) return;
        for (final r in results) {
          if ((r.device.platformName.isNotEmpty ? r.device.platformName : r.advertisementData.advName).contains("PORTAO") || r.advertisementData.serviceUuids.any((u) => u.toString().toLowerCase() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b")) {
            conectando = true; await FlutterBluePlus.stopScan();
            try {
              await r.device.connect(timeout: const Duration(seconds: 10), autoConnect: false);
              if (defaultTargetPlatform == TargetPlatform.android) try { await r.device.requestMtu(512); } catch(_) {}
              await Future.delayed(const Duration(milliseconds: 500));
              for (final svc in await r.device.discoverServices()) if (svc.uuid.toString() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b") {
                for (final c in svc.characteristics) if (c.uuid.toString() == "beb5483e-36e1-4688-b7f5-ea07361b26a8") {
                  try { await c.setNotifyValue(true); } catch (_) {}
                  final cmd = "SEC|${Uri.encodeComponent(CryptoHelper.criptografar("${widget.userData['email'] ?? ''};${DateTime.now().millisecondsSinceEpoch};ONL"))}|$rele";
                  bool res = false; String sFinal = "TIMEOUT";
                  final nSub = c.onValueReceived.listen((val) async {
                    final rep = utf8.decode(val);
                    if (rep == "OK") { res = true; sFinal = "OK"; } else if (rep == "BLKD") { res = true; sFinal = "BLKD"; if (globalNavigatorKey.currentContext != null) { final prefs = await SharedPreferences.getInstance(); await prefs.remove('off_user_data'); await prefs.remove('off_senha'); await FirebaseAuth.instance.signOut(); Navigator.pushAndRemoveUntil(globalNavigatorKey.currentContext!, MaterialPageRoute(builder: (_) => const TelaLogin()), (_) => false); showDialog(context: globalNavigatorKey.currentContext!, barrierDismissible: false, builder: (c) => AlertDialog(title: const Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 10), Text("Acesso Negado")]), content: const Text("Você não tem permissão da administração para abrir o portão."), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("FECHAR"))])); } } else if (rep == "ERR") { res = true; sFinal = "ERR"; } else if (rep == "MOV") { res = true; sFinal = "MOV"; }
                  });
                  try { await c.write(utf8.encode(cmd), withoutResponse: false); } catch (_) {}
                  for (int i = 0; i < 15; i++) { await Future.delayed(const Duration(milliseconds: 500)); if (res) break; }
                  nSub.cancel(); await r.device.disconnect(); if (!completer.isCompleted) completer.complete(sFinal); return;
                }
              }
              await r.device.disconnect();
            } catch (_) {}
            if (!completer.isCompleted) completer.complete("ERR"); return;
          }
        }
      });
      try { await FlutterBluePlus.startScan(withServices: [Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b")], timeout: const Duration(seconds: 6)); } catch(_) {}
      final resultado = await completer.future.timeout(const Duration(seconds: 8), onTimeout: () => "TIMEOUT");
      sub.cancel(); try { await FlutterBluePlus.stopScan(); } catch(_) {}
      return resultado;
    } catch (_) { return "ERR"; }
  }

  void _enviarComandoAbertura(Map<String, dynamic> dataPortao, String idPortao, {bool usarBluetooth = false}) async {
    final nomePortao = dataPortao['nome'], rele = dataPortao['codigo'], idDispositivo = dataPortao['id_box'], tempoAbertura = dataPortao['tempo_abertura'] ?? 15;
    mostrarBrilhoNeon(context); setState(() => _processandoLocal = true); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(usarBluetooth ? "Conectando via Bluetooth..." : "Aguarde..."), duration: const Duration(seconds: 1)));
    
    if (usarBluetooth) {
      final statusBle = await _abrirViaBluetooth(idDispositivo, rele);
      if (statusBle == "OK") { registrarAuditoria(widget.userData['sindico_vinculado'], "Abertura Bluetooth (Offline)", "Acesso Mobile", "Portão $nomePortao acionado localmente por ${widget.userData['nome']}.").catchError((_) => null); setState(() => _processandoLocal = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Portão abrindo"), backgroundColor: Colors.green)); await Future.delayed(const Duration(milliseconds: 2000)); SystemNavigator.pop(); return; }
      else if (statusBle == "MOV") { setState(() => _processandoLocal = false); await Future.delayed(const Duration(milliseconds: 2000)); SystemNavigator.pop(); return; }
      else if (statusBle == "BLKD") { setState(() => _processandoLocal = false); return; }
      else { setState(() => _processandoLocal = false); return; }
    }

    bool temInternet = true; 
    if (!kIsWeb) { 
      try { if ((await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2))).isEmpty) temInternet = false; } catch (_) { temInternet = false; }
    }
    if (!temInternet) { setState(() => _processandoLocal = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text("Sem internet. Use o botão de Bluetooth ao lado.", style: TextStyle(color: Colors.white)), duration: Duration(seconds: 4))); return; }

    try {
      final docAtual = await FirebaseFirestore.instance.collection('portoes').doc(idPortao).get(const GetOptions(source: Source.server)).timeout(const Duration(milliseconds: 800));
      if (docAtual.exists && docAtual.data()!['ultima_abertura'] != null && DateTime.now().difference((docAtual.data()!['ultima_abertura'] as Timestamp).toDate()).inSeconds.abs() < tempoAbertura) { setState(() => _processandoLocal = false); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.orange, content: Text("Aguarde! Portão já está em movimento.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))); await Future.delayed(const Duration(milliseconds: 2000)); SystemNavigator.pop(); return; }
    } catch(_) {}
    FirebaseFirestore.instance.collection('portoes').doc(idPortao).update({'ultima_abertura': FieldValue.serverTimestamp()}).catchError((_) => null);
    GerenciadorDeTunel.registrarMovimentoRele(rele);

    try {
      final token = FirebaseAuth.instance.currentUser != null ? await FirebaseAuth.instance.currentUser!.getIdToken() : '';
      final response = await http.post(Uri.parse('https://us-central1-logichome-a9808.cloudfunctions.net/solicitarAberturaPortao'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({'data': {'id_dispositivo': idDispositivo, 'id_portao': idPortao, 'rele': rele, 'operador': widget.userData['nome']}}));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body)['result'] ?? jsonDecode(response.body)['data'];
        if (!mounted) return;
        if (result != null && result['sucesso'] == false && result['motivo'] == 'em_movimento') { ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), backgroundColor: Colors.orange.shade800, content: const Row(children: [Icon(Icons.warning, color: Colors.white), SizedBox(width: 10), Expanded(child: Text("Aguarde! Portão já está em movimento.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]))); setState(() => _processandoLocal = false); await Future.delayed(const Duration(milliseconds: 2000)); SystemNavigator.pop(); return; }
        else if (result != null && result['sucesso'] == false && result['motivo'] == 'offline') { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("O Servidor da Portaria está Offline. Abertura remota indisponível.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))); setState(() => _processandoLocal = false); await Future.delayed(const Duration(milliseconds: 3000)); SystemNavigator.pop(); return; }
        await registrarAuditoria(widget.userData['sindico_vinculado'], "Abertura Pelo Morador", "Interfonia/App", "Portão $nomePortao acionado por ${widget.userData['nome']}.");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.green, content: Text("Portão abrindo", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
        setState(() => _processandoLocal = false); await Future.delayed(const Duration(milliseconds: 2000)); SystemNavigator.pop();
      } else throw Exception("Falha de conexão com a Placa.");
    } catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Colors.red, content: Text("Falha ao comunicar com o portão."))); setState(() => _processandoLocal = false); }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Portões Encontrados", style: TextStyle(fontWeight: FontWeight.bold)), actions: const [BotaoTrocarTema()]),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('usuarios').doc(widget.userData['sindico_vinculado']).get(),
        builder: (context, snapConfig) {
          if (!snapConfig.hasData) return const Center(child: CircularProgressIndicator());
          
          String? nasc = widget.userData['data_nascimento'];
          int idadeMorador = 99;
          if (nasc != null && nasc.isNotEmpty) {
            try {
              final partes = nasc.split('/');
              DateTime dtNasc = DateTime(int.parse(partes[2]), int.parse(partes[1]), int.parse(partes[0]));
              DateTime hoje = DateTime.now();
              idadeMorador = hoje.year - dtNasc.year;
              if (hoje.month < dtNasc.month || (hoje.month == dtNasc.month && hoje.day < dtNasc.day)) idadeMorador--;
            } catch (_) {}
          }
          
          final idadeExigida = (snapConfig.data!.data() as Map<String, dynamic>)['idade_minima_portoes'] ?? 18;
          if (idadeMorador < idadeExigida) {
            return Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock, size: 100, color: colorScheme.error), const SizedBox(height: 20), Text("Acesso Restrito", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.error)), const SizedBox(height: 10), Text("Você não possui idade mínima ($idadeExigida anos) para abrir portões.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))])));
          }

          return Column(children: [const SizedBox(height: 30), FadeTransition(opacity: _pulseController, child: Icon(Icons.sensor_door, color: colorScheme.primary, size: 80)), const SizedBox(height: 15), Text("Sinal Detectado!", style: TextStyle(color: colorScheme.primary, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1)), const SizedBox(height: 5), Text("Você está no raio de alcance do portão.", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14)), const SizedBox(height: 30), if (_processandoLocal) const Padding(padding: EdgeInsets.all(20), child: Column(children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Tentando conexão direta...")])), Expanded(child: FutureBuilder<QuerySnapshot>(future: FirebaseFirestore.instance.collection('portoes').where('sindico_vinculado', isEqualTo: widget.userData['sindico_vinculado']).where('permite_morador', isEqualTo: true).get(const GetOptions(source: Source.serverAndCache)), builder: (context, snap) { if (!snap.hasData) return const Center(child: CircularProgressIndicator()); if (snap.data!.docs.isEmpty) return Center(child: Text("Você não possui portões liberados.", style: TextStyle(color: colorScheme.onSurface))); return ListView.builder(itemCount: snap.data!.docs.length, itemBuilder: (ctx, i) { final data = snap.data!.docs[i].data() as Map<String, dynamic>; return Padding(padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15), child: SliderAbrirPortao(nomePortao: data['nome'].toString().toUpperCase(), onSlid: () => _enviarComandoAbertura(data, snap.data!.docs[i].id), onBluetoothPressed: () => _enviarComandoAbertura(data, snap.data!.docs[i].id, usarBluetooth: true))); }); }))]);
        }
      )
    );
  }
}

class SliderAbrirPortao extends StatefulWidget {
  final VoidCallback onSlid; final String nomePortao; final VoidCallback? onBluetoothPressed;
  const SliderAbrirPortao({super.key, required this.onSlid, required this.nomePortao, this.onBluetoothPressed});
  @override
  State<SliderAbrirPortao> createState() => _SliderAbrirPortaoState();
}

class _SliderAbrirPortaoState extends State<SliderAbrirPortao> {
  double _dragPosition = 0.0;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      double h = constraints.maxHeight > 0 && constraints.maxHeight < 75 ? constraints.maxHeight : 75.0;
      double availableWidth = widget.onBluetoothPressed != null ? constraints.maxWidth - (h + 20) : constraints.maxWidth;
      double maxDrag = availableWidth - (h + 4); if (maxDrag < 0) maxDrag = 0;
      final progresso = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0, corBotaoAtual = Color.lerp(colorScheme.primary, Colors.greenAccent, progresso) ?? colorScheme.primary, corBordaAtual = Color.lerp(colorScheme.primary.withValues(alpha:0.5), Colors.greenAccent.withValues(alpha:0.8), progresso) ?? colorScheme.primary.withValues(alpha:0.5), corSombra = Color.lerp(colorScheme.primary.withValues(alpha:0.5), Colors.greenAccent.withValues(alpha:1.0), progresso) ?? colorScheme.primary.withValues(alpha:0.5), blurSombra = 10 + (25 * progresso);
      
      Widget slider = Container(height: h, width: availableWidth, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest.withValues(alpha:0.5), borderRadius: BorderRadius.circular(h/2), border: Border.all(color: corBordaAtual, width: 2), boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha:0.2 * progresso), blurRadius: 15)]), child: Stack(children: [Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(progresso > 0.8 ? "ENVIANDO SINAL..." : "ABRIR VIA INTERNET (4G) >>>", style: TextStyle(color: Color.lerp(colorScheme.onSurface, Colors.white, progresso), fontWeight: FontWeight.bold, fontSize: h < 50 ? 10 : 12, letterSpacing: 1)), if (progresso <= 0.2) Padding(padding: const EdgeInsets.only(top: 2), child: Text("Use apenas se estiver LONGE do portão", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: h < 50 ? 8 : 9, fontWeight: FontWeight.bold)))])), Positioned(left: _dragPosition, child: GestureDetector(onHorizontalDragUpdate: (details) => setState(() { _dragPosition += details.delta.dx; if (_dragPosition < 0) _dragPosition = 0; if (_dragPosition > maxDrag) _dragPosition = maxDrag; }), onHorizontalDragEnd: (_) { if (_dragPosition > maxDrag * 0.8) { widget.onSlid(); setState(() => _dragPosition = 0.0); } else setState(() => _dragPosition = 0.0); }, child: Container(height: h, width: h, decoration: BoxDecoration(color: corBotaoAtual, shape: BoxShape.circle, boxShadow: [BoxShadow(color: corSombra, blurRadius: blurSombra, spreadRadius: progresso * 5)]), child: Icon(Icons.cloud, color: progresso > 0.6 ? Colors.black87 : colorScheme.onPrimary, size: h * 0.4))))]));
      
      if (widget.onBluetoothPressed != null) {
        return Row(children: [
          Expanded(child: slider),
          const SizedBox(width: 20),
          Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
            GestureDetector(onTap: widget.onBluetoothPressed, child: Container(height: h, width: h, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.blue, Colors.lightBlueAccent], begin: Alignment.topLeft, end: Alignment.bottomRight), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha:0.6), blurRadius: 12, spreadRadius: 2)]), child: Icon(Icons.bluetooth, color: Colors.white, size: h * 0.4))),
            Positioned(bottom: -8, child: IgnorePointer(child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 1.5), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)]), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.bolt, color: Colors.white, size: 12), Text("RÁPIDO", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1))]))))
          ])
        ]);
      }
      return slider;
    });
  }
}

class TelaConfiguracaoServidorLocal extends StatefulWidget {
  final String emailSindico;
  const TelaConfiguracaoServidorLocal({super.key, required this.emailSindico});
  @override
  State<TelaConfiguracaoServidorLocal> createState() => _TelaConfiguracaoServidorLocalState();
}

class _TelaConfiguracaoServidorLocalState extends State<TelaConfiguracaoServidorLocal> {
  bool _isServidor = false, _carregando = true;

  @override
  void initState() { super.initState(); _carregarConfiguracao(); }

  Future<void> _carregarConfiguracao() async { final prefs = await SharedPreferences.getInstance(); setState(() { _isServidor = prefs.getBool('is_servidor_local') ?? false; _carregando = false; }); }

  Future<void> _toggleServidor(bool valor) async {
    setState(() => _carregando = true);
    final prefs = await SharedPreferences.getInstance(); await prefs.setBool('is_servidor_local', valor);
    if (valor) await GerenciadorDeTunel.iniciar(widget.emailSindico); else GerenciadorDeTunel.desligarTudo();
    setState(() { _isServidor = valor; _carregando = false; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(valor ? "Este PC agora é o Servidor Principal (Câmeras e Portões ativos)!" : "Motores desligados. Este PC agora é um terminal secundário."), backgroundColor: valor ? Colors.green : Colors.orange));
  }

  Future<void> _fixarIpWindows() async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(title: const Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 10), Text("Atenção!")]), content: const Text("Ao cravar o IP, a placa de rede do Windows será reiniciada. A internet vai piscar e o aplicativo precisará ser FECHADO automaticamente para não travar os motores de vídeo.\n\nDeseja prosseguir?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCELAR")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white), onPressed: () async {
      Navigator.pop(ctx); setState(() => _carregando = true);
      try {
        GerenciadorDeTunel.desligarTudo(); await Future.delayed(const Duration(seconds: 1));
        final scriptFile = File('${(await getTemporaryDirectory()).path}\\fix_ip.ps1');
        await scriptFile.writeAsString('\$net = Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select-Object -First 1\nif (\$net -eq \$null) { exit }\n\$ifIndex = \$net.InterfaceIndex\n\$ifAlias = (Get-NetAdapter -InterfaceIndex \$ifIndex).InterfaceAlias\n\$ip = (Get-NetIPAddress -InterfaceIndex \$ifIndex -AddressFamily IPv4).IPAddress\n\$ipParts = \$ip.Split(\'.\')\n\$newIp = \$ipParts[0] + \'.\' + \$ipParts[1] + \'.\' + \$ipParts[2] + \'.200\'\n\$gw = \$net.NextHop\nnetsh interface ipv4 set address name="\$ifAlias" static \$newIp 255.255.255.0 \$gw\nnetsh interface ipv4 set dnsservers name="\$ifAlias" static 8.8.8.8 primary validate=no\nnetsh interface ipv4 add dnsservers name="\$ifAlias" 8.8.4.4 index=2 validate=no\n');
        if (mounted) showDialog(context: context, barrierDismissible: false, builder: (c) => const AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: Colors.red), SizedBox(height: 20), Text("Mudando o IP do Windows...\nO aplicativo será fechado em 5 segundos.", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)), SizedBox(height: 10), Text("Aguarde o Prompt de Comando confirmar e abra o app novamente.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey))])));
        Process.run('powershell', ['-Command', 'Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File ${scriptFile.path}" -Verb RunAs']);
        await Future.delayed(const Duration(seconds: 5)); exit(0);
      } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erro: $e"), backgroundColor: Colors.red)); setState(() => _carregando = false); }
    }, child: const Text("SIM, CRAVAR IP E FECHAR"))]));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_carregando) return const Center(child: CircularProgressIndicator());
    return Scaffold(body: Column(children: [const Padding(padding: EdgeInsets.all(16.0), child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, child: Text("Configuração de Hardware Local", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))))), Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: _isServidor ? Colors.green : Colors.grey.withValues(alpha:0.5), width: 2)), child: Padding(padding: const EdgeInsets.all(30), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.dns, size: 50, color: _isServidor ? Colors.green : Colors.grey), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Este Computador é o Servidor?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text("Se houver mais de um computador na portaria, APENAS UM deve ficar marcado como servidor para evitar envio de sinais duplicados aos portões e conflito de câmeras.", style: TextStyle(color: colorScheme.onSurfaceVariant))]))]), const Divider(height: 40), Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: _isServidor ? Colors.green.withValues(alpha:0.1) : colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: SwitchListTile(title: Text(_isServidor ? "🟢 LIGADO: MODO SERVIDOR ATIVADO" : "⚫ DESLIGADO: MODO TERMINAL (Thin Client)", style: TextStyle(fontWeight: FontWeight.bold, color: _isServidor ? Colors.green : colorScheme.onSurface)), subtitle: Text(_isServidor ? "Este computador é o cérebro. Ele está processando as imagens RTSP das câmeras e ouvindo os cliques no app para abrir as placas Control iD." : "Este computador atua apenas como controle remoto. Quando o porteiro clicar em 'Abrir Portão', o sinal será enviado pela nuvem para o Servidor processar.", style: const TextStyle(fontSize: 12)), value: _isServidor, activeThumbColor: Colors.green, onChanged: _toggleServidor))]))), const SizedBox(height: 20), if (_isServidor) Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: Padding(padding: const EdgeInsets.all(30), child: Row(children: [Icon(Icons.router, size: 50, color: colorScheme.primary), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Travar IP do Windows", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text("Para garantir que a placa IoT não perca a comunicação com este PC caso o roteador reinicie, trave o IP desta máquina.", style: TextStyle(color: colorScheme.onSurfaceVariant))])), const SizedBox(width: 20), ElevatedButton.icon(style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20), backgroundColor: colorScheme.primary, foregroundColor: colorScheme.onPrimary), icon: const Icon(Icons.lock), label: const Text("CRAVAR IP (.200)", style: TextStyle(fontWeight: FontWeight.bold)), onPressed: _fixarIpWindows)])))])))]));
  }
}

class TelaMinhaAssinaturaSaaS extends StatelessWidget {
  final String emailSindico;
  const TelaMinhaAssinaturaSaaS({super.key, required this.emailSindico});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text("Minha Assinatura SaaS")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Icon(Icons.workspace_premium, size: 50, color: colorScheme.primary),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Minha Licença de Software", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("Gerencie seus pagamentos e comprovantes.", style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('usuarios').doc(emailSindico).snapshots(),
            builder: (context, snapUser) {
              if (!snapUser.hasData || !snapUser.data!.exists) return const SizedBox.shrink();
              final data = snapUser.data!.data() as Map<String, dynamic>;
              final linkFatura = data['url_fatura_atual'] ?? '';
              final statusFatura = data['status_fatura'] ?? 'PAGA';
              
              if (statusFatura == 'PAGA' || linkFatura.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green)),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 10),
                        Text("Sua assinatura está em dia!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }
              
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Card(
                  color: colorScheme.errorContainer,
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: colorScheme.error, size: 30),
                            const SizedBox(width: 10),
                            Text("Fatura em Aberto", style: TextStyle(color: colorScheme.error, fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text("Você possui uma fatura pendente. Clique no botão abaixo para acessar o boleto ou PIX no ambiente seguro do banco.", style: TextStyle(color: colorScheme.onErrorContainer)),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError, padding: const EdgeInsets.all(15)),
                            icon: const Icon(Icons.payment),
                            label: const Text("IR PARA O PAGAMENTO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            onPressed: () => launchUrl(Uri.parse(linkFatura), mode: LaunchMode.externalApplication),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.only(left: 20, top: 20, bottom: 10),
            child: Text("Histórico de Comprovantes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('receitas_saas').where('sindico_vinculado', isEqualTo: emailSindico).orderBy('data_pagamento', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return const Center(child: Text("Erro ao carregar faturas."));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                if (snap.data!.docs.isEmpty) return const Center(child: Text("Nenhum histórico de pagamento encontrado."));
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: snap.data!.docs.length,
                  itemBuilder: (ctx, i) {
                    final data = snap.data!.docs[i].data() as Map<String, dynamic>;
                    final dataStr = data['data_pagamento'] != null ? DateFormat('dd/MM/yyyy HH:mm').format((data['data_pagamento'] as Timestamp).toDate()) : "Data Indisponível";
                    return Card(
                      shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.green, width: 1), borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.check, color: Colors.white)),
                        title: const Text("Licença SaaS Paga", style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Pago em: $dataStr\nMétodo: ${data['forma_pagamento']}"),
                        trailing: Text("R\$ ${(data['valor'] ?? 0).toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}