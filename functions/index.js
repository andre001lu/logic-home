const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onTaskDispatched } = require("firebase-functions/v2/tasks");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");
const axios = require("axios"); 
const { defineSecret } = require('firebase-functions/params');

// Inicialização segura do cofre
const asaasApiKeySecret = defineSecret('ASAAS_API_KEY');

// O Firebase v2 já injeta o .env automaticamente via dotenvx. 
// A inicialização foi blindada com try/catch para evitar falhas de leitura na RAM.
try {
  admin.initializeApp();
} catch (e) {
  // Ignora erro se já estiver inicializado
}

/** ============================================================================
 * MOTOR DE TELEMETRIA SAAS (O "BALDE" ANTI-HOTSPOT E ANTI-CUSTOS)
 * ============================================================================ */
// Variável global na memória da Cloud Function para acumular as contagens sem tocar no banco
const bufferTelemetria = {};
let timerTelemetriaAtivo = false;

async function registrarTelemetria(sindicoEmail, moduloOperacao, quantidade = 1) {
  if (!sindicoEmail) return;
  
  const data = new Date();
  const mesAno = `${data.getMonth() + 1}_${data.getFullYear()}`; 
  const docId = `${mesAno}_${sindicoEmail}`;

  // Inicializa o "balde" para este condomínio se não existir na memória RAM
  if (!bufferTelemetria[docId]) {
    bufferTelemetria[docId] = {
      sindico_vinculado: sindicoEmail,
      mes_ano: mesAno,
      contadores: {}
    };
  }

  // Pinga a gota d'água no balde (Memória RAM - Custo Zero)
  if (!bufferTelemetria[docId].contadores[`uso_${moduloOperacao}`]) {
     bufferTelemetria[docId].contadores[`uso_${moduloOperacao}`] = 0;
  }
  bufferTelemetria[docId].contadores[`uso_${moduloOperacao}`] += quantidade;

  // Se não tem ninguém esvaziando o balde, contrata o "faxineiro" para daqui a 10 segundos
  if (!timerTelemetriaAtivo) {
    timerTelemetriaAtivo = true;
    setTimeout(async () => {
      try {
        const batch = admin.firestore().batch();
        
        // Pega todos os baldes que encheram nos últimos 10 segundos e prepara a gravação
        for (const idDoc in bufferTelemetria) {
          const info = bufferTelemetria[idDoc];
          const ref = admin.firestore().collection('telemetria_saas').doc(idDoc);
          
          const updateData = {
            sindico_vinculado: info.sindico_vinculado,
            mes_ano: info.mes_ano,
            ultima_acao: admin.firestore.FieldValue.serverTimestamp()
          };

          // Transforma os números absolutos do balde em "incrementos" oficiais pro Firebase
          for (const modulo in info.contadores) {
            updateData[modulo] = admin.firestore.FieldValue.increment(info.contadores[modulo]);
          }

          batch.set(ref, updateData, { merge: true });
          delete bufferTelemetria[idDoc]; // Esvazia o balde
        }

        // Faz 1 única gravação no banco de dados contendo centenas de operações
        await batch.commit();
      } catch (error) {
        console.error("Erro ao descarregar o balde de telemetria:", error);
      } finally {
        timerTelemetriaAtivo = false;
      }
    }, 10000); // O relógio de 10 segundos
  }
}

/** ============================================================================
 * FUNÇÃO 1: enviarCodigoAutenticacao (Valida e Gera o PIN)
 * ============================================================================ */
exports.enviarCodigoAutenticacao = onCall(async (request) => {
  const data = request.data;
  const { email, nome, perfil, id_condominio } = data;

  if (!email || !nome) {
    throw new HttpsError("invalid-argument", "E-mail e nome são obrigatórios.");
  }

  // MÁGICA: O Leão de Chácara do E-mail. Controla tentativas e aplica a "geladeira" de 60 minutos.
  const emailAlvo = email.toLowerCase().trim();
  const rateLimitRef = admin.firestore().collection('controle_emails').doc(emailAlvo);
  const limitDoc = await rateLimitRef.get();
  const agora = new Date();

  if (limitDoc.exists) {
    const limitData = limitDoc.data();
    
    // 1. O usuário está de castigo na geladeira?
    if (limitData.bloqueado_ate && limitData.bloqueado_ate.toDate() > agora) {
       const minutosRestantes = Math.ceil((limitData.bloqueado_ate.toDate() - agora) / 60000);
       throw new HttpsError("resource-exhausted", `Limite excedido. Aguarde ${minutosRestantes} minuto(s) para tentar novamente.`);
    }

    // 2. Analisa a janela de 15 minutos
    const primeiraTentativa = limitData.primeira_tentativa ? limitData.primeira_tentativa.toDate() : agora;
    const diferencaMinutos = (agora - primeiraTentativa) / 60000;

    if (diferencaMinutos <= 15) {
      if (limitData.tentativas >= 4) {
         // 3. Estourou o limite das 4 tentativas! Aplica o bloqueio de 60 minutos.
         const bloqueioAte = new Date(agora.getTime() + 60 * 60000); 
         await rateLimitRef.set({ bloqueado_ate: admin.firestore.Timestamp.fromDate(bloqueioAte) }, { merge: true });
         throw new HttpsError("resource-exhausted", "Muitas tentativas. Por segurança, aguarde 60 minutos para solicitar um novo código.");
      } else {
         // Ainda tem créditos na janela de 15 minutos, apenas anota mais um.
         await rateLimitRef.update({ tentativas: admin.firestore.FieldValue.increment(1) });
      }
    } else {
      // Já passou de 15 minutos, zera a prancheta.
      await rateLimitRef.set({ tentativas: 1, primeira_tentativa: admin.firestore.Timestamp.fromDate(agora), bloqueado_ate: null });
    }
  } else {
    // Primeira vez que esta pessoa pede um código
    await rateLimitRef.set({ tentativas: 1, primeira_tentativa: admin.firestore.Timestamp.fromDate(agora), bloqueado_ate: null });
  }

  const userSnap = await admin.firestore().collection("usuarios").doc(email).get();
  if (userSnap.exists) {
    throw new HttpsError("already-exists", "Este e-mail já está cadastrado.");
  }

  let sindicoVinculado = "";
  let nomeCondominio = "";

  if (perfil === "morador") {
    if (!id_condominio) {
      throw new HttpsError("invalid-argument", "Código do condomínio é obrigatório.");
    }
    
    const condoSnap = await admin.firestore().collection("usuarios")
      .where("perfil", "==", "sindico")
      .where("id_condominio", "==", id_condominio.toUpperCase())
      .limit(1).get();

    if (condoSnap.empty) {
      throw new HttpsError("not-found", "Código de condomínio inválido.");
    }

    sindicoVinculado = condoSnap.docs[0].id;
    nomeCondominio = condoSnap.docs[0].data().condominio || "Condomínio";
  }

  const codigoGerado = Math.floor(100000 + Math.random() * 900000).toString();

  const transporter = nodemailer.createTransport({
    service: 'gmail', 
    auth: { user: 'logichome.suporte@gmail.com', pass: process.env.EMAIL_PASSWORD }
  });

  const mailOptions = {
    from: '"Logic Home" <logichome.suporte@gmail.com>',
    to: email,
    subject: `Seu Código de Verificação: ${codigoGerado}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #ddd; padding: 20px;">
        <div style="text-align: center; background-color: #0D47A1; padding: 10px;">
            <h1 style="color: white; margin: 0;">Logic Home</h1>
        </div>
        <h2 style="color: #333;">Olá, ${nome}!</h2>
        <p style="font-size: 16px; color: #555;">Recebemos uma solicitação de cadastro no sistema.</p>
        <div style="text-align: center; margin: 30px 0; padding: 20px; background-color: #f5f5f5; border-radius: 10px;">
            <p style="margin: 0; font-size: 14px; color: #777;">SEU CÓDIGO DE VERIFICAÇÃO:</p>
            <h1 style="margin: 10px 0; font-size: 48px; letter-spacing: 10px; color: #0D47A1;">${codigoGerado}</h1>
        </div>
        <p style="font-size: 14px; color: #888;">Insira este código no aplicativo para validar seu acesso.</p>
      </div>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    return { 
      status: "sucesso", 
      codigo_gerado: codigoGerado, 
      sindico_vinculado: sindicoVinculado,
      nome_condominio: nomeCondominio
    };
  } catch (error) {
    throw new HttpsError("internal", "Erro ao disparar e-mail.");
  }
});

/** ============================================================================
 * FUNÇÃO EXTRA: validarEmailReset
 * ============================================================================ */
exports.validarEmailReset = onCall(async (request) => {
  const email = request.data.email;
  if (!email) throw new HttpsError("invalid-argument", "E-mail é obrigatório.");

  const doc = await admin.firestore().collection("usuarios").doc(email).get();
  if (!doc.exists) {
    throw new HttpsError("not-found", "E-mail não cadastrado no sistema.");
  }
  return { sucesso: true };
});

/** ============================================================================
 * FUNÇÃO 2: criarUsuarioSaaS
 * ============================================================================ */
exports.criarUsuarioSaaS = onCall(async (request) => {
  const data = request.data;
  const auth = request.auth;

  if (auth) {
    const callerDoc = await admin.firestore().collection("usuarios").doc(auth.token.email).get();
    if (callerDoc.exists) {
      const perfil = callerDoc.data()?.perfil;
      if (perfil !== "master" && perfil !== "sindico" && perfil !== "tecnico") {
        throw new HttpsError("permission-denied", "Operação não autorizada.");
      }
    }
  }

  try {
    let sindicoFinal = data.sindico_vinculado;

    if (data.perfil === "morador" && !sindicoFinal && data.id_condominio) {
      const query = await admin.firestore().collection("usuarios")
        .where("perfil", "==", "sindico")
        .where("id_condominio", "==", data.id_condominio)
        .limit(1)
        .get();

      if (query.empty) throw new HttpsError("not-found", "Condomínio não localizado.");
      sindicoFinal = query.docs[0].id; 
    }

    const userRecord = await admin.auth().createUser({
      email: data.email,
      password: data.senha,
      displayName: data.nome,
      emailVerified: data.email_verificado || false,
    });

    await admin.auth().setCustomUserClaims(userRecord.uid, {
      perfil: data.perfil,
      sindico_vinculado: data.perfil === "sindico" ? data.email : (sindicoFinal || "")
    });

    const userData = {
      uid: userRecord.uid,
      nome: data.nome,
      email: data.email,
      perfil: data.perfil,
      status: data.perfil === "morador" ? "pendente" : "aprovado",
      servico_ativo: data.perfil === "sindico", 
      sindico_vinculado: data.perfil === "sindico" ? data.email : (sindicoFinal || ""),
      exige_troca_senha: data.exige_troca_senha || false,
      data_registro: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (data.condominio) userData.condominio = data.condominio;
    if (data.id_condominio) userData.id_condominio = data.id_condominio;
    if (data.telefone) userData.telefone = data.telefone;
    if (data.bloco) userData.bloco = data.bloco;
    if (data.ap) userData.ap = data.ap;
    if (data.aceitou_termos) userData.aceitou_termos = data.aceitou_termos;
    if (data.data_expiracao) userData.data_expiracao = admin.firestore.Timestamp.fromDate(new Date(data.data_expiracao));

    await admin.firestore().collection("usuarios").doc(data.email).set(userData);
    return { sucesso: true, uid: userRecord.uid };

  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "Este e-mail já está cadastrado.");
    }
    throw new HttpsError("internal", error.message);
  }
});

/** ============================================================================
 * FUNÇÃO 3: webhookiDBox (Hardware Control iD) 
 * ============================================================================ */
exports.webhookiDBox = onRequest(async (request, response) => {
  if (request.method !== "POST" && request.method !== "GET") return response.status(405).send("Acesso Negado");

  const authHeader = request.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) return response.status(401).send("Token ausente");
  
  const token = authHeader.split("Bearer ")[1].trim();

  try {
    let payload = request.body;
    if (Buffer.isBuffer(payload)) {
      payload = payload.toString('utf8');
      try { payload = JSON.parse(payload); } catch(e) {}
    }

    if (request.method === "POST") {
      let ehEventoUtil = false;
      if (payload && payload.data && payload.data.card_value) ehEventoUtil = true;
      else if (payload && payload.event === 'button_pressed') ehEventoUtil = true;
      else if (payload && payload.status_comando === 'concluido' && payload.id_comando) ehEventoUtil = true;

      if (!ehEventoUtil) return response.status(200).send("Online"); 
    }

    const snapshot = await admin.firestore().collection("idboxes").where("token", "==", token).limit(1).get();
    if (snapshot.empty) return response.status(403).send("Máquina não reconhecida.");

    const maquinaDoc = snapshot.docs[0];
    const maquinaData = maquinaDoc.data();
    const macAddress = maquinaData.id_unico; 
    const sindicoVinculado = maquinaData.sindico_vinculado || "desconhecido";

    let deveAtualizarBanco = false;

    if (request.method === "POST") {
      deveAtualizarBanco = true;
    } else {
      if (!maquinaData.ultimo_sinal) {
        deveAtualizarBanco = true;
      } else {
        const ultimoSinalData = maquinaData.ultimo_sinal.toDate();
        const diferencaMinutos = (new Date() - ultimoSinalData) / (1000 * 60);
        
        if (diferencaMinutos > 15) {
          deveAtualizarBanco = true;
        }
      }
    }

    if (deveAtualizarBanco) {
      await maquinaDoc.ref.update({ 
        status: "online", 
        ultimo_sinal: admin.firestore.FieldValue.serverTimestamp() 
      });
    }

    if (request.method === "GET") {
      const comandos = await admin.firestore().collection('comandos_iot')
        .where('id_dispositivo', '==', macAddress).where('status', '==', 'pendente').limit(1).get();

      if (comandos.empty) return response.status(200).json(null);

      const docComando = comandos.docs[0];
      await docComando.ref.update({ status: 'processando_no_hardware' });

      return response.status(200).json({
        acao: 'abrir_portao', rele: docComando.data().rele || '1', operador: docComando.data().operador, id_comando: docComando.id 
      });
    }

    if (request.method === "POST") {
      if (payload.status_comando === 'concluido' && payload.id_comando) {
          await admin.firestore().collection('comandos_iot').doc(payload.id_comando).update({
              status: 'concluido', data_execucao: admin.firestore.FieldValue.serverTimestamp()
          });
          return response.status(200).json({ success: true });
      }

      let detalhes = `Monitoramento hardware.`;
      if (payload.data && payload.data.card_value) detalhes = `Cartão lido: ${payload.data.card_value}`;
      else if (payload.event === 'button_pressed') detalhes = `Botão saída pressionado.`;

      await admin.firestore().collection("auditoria").add({
        sindico_vinculado: sindicoVinculado, operador: "Físico", acao: `Acesso ${maquinaData.nome}`,    
        modulo: "Controle de Acessos", detalhes: detalhes, dados_brutos: JSON.parse(JSON.stringify(payload)), 
        data_hora: admin.firestore.FieldValue.serverTimestamp(), plataforma: "IoT",
      });

      return response.status(200).send("Recebido!");
    }
  } catch (error) {
    response.status(500).send(`Erro: ${error.message}`);
  }
});

/** ============================================================================
 * FUNÇÃO 4: solicitarAberturaPortao
 * ============================================================================ */
exports.solicitarAberturaPortao = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Usuário não autenticado. Acesso negado.");
  }

  const payload = request.data;
  if (!payload.id_dispositivo || !payload.id_portao) {
    throw new HttpsError("invalid-argument", "Faltam dados do dispositivo ou portão.");
  }

  try {
    const portaoRef = admin.firestore().collection('portoes').doc(payload.id_portao);
    const portaoDoc = await portaoRef.get();
    
    if (!portaoDoc.exists) {
       throw new HttpsError("not-found", "Portão não encontrado.");
    }

    // MÁGICA: A Nuvem agora olha se o Servidor Local (PC) ou a Placa estão online antes de prometer abrir!
    const placaQuery = await admin.firestore().collection('idboxes')
      .where('id_unico', '==', payload.id_dispositivo)
      .limit(1)
      .get();
      
    if (!placaQuery.empty) {
      if (placaQuery.docs[0].data().status !== 'online') {
        return { sucesso: false, motivo: 'offline' };
      }
    }

    const dataPortao = portaoDoc.data();
    const tempoPercurso = dataPortao.tempo_abertura || 15; 
    
    if (dataPortao.ultimo_acionamento) {
      const ultimoAcionamento = dataPortao.ultimo_acionamento.toDate();
      const agora = new Date();
      const diferencaSegundos = (agora - ultimoAcionamento) / 1000;

      if (diferencaSegundos < tempoPercurso) {
        return { 
          sucesso: false, 
          motivo: 'em_movimento', 
          tempo_restante: Math.ceil(tempoPercurso - diferencaSegundos) 
        };
      }
    }

    await portaoRef.update({ 
      ultimo_acionamento: admin.firestore.FieldValue.serverTimestamp() 
    });

    await admin.firestore().collection('comandos_iot').add({
      sindico_vinculado: dataPortao.sindico_vinculado, 
      id_dispositivo: payload.id_dispositivo, 
      rele: payload.rele || '1', 
      comando: 'abrir_portao',
      operador: payload.operador || request.auth.token.email, 
      status: 'pendente', 
      data_hora: admin.firestore.FieldValue.serverTimestamp()
    });

    return { sucesso: true };
  } catch (error) {
    console.error("Erro ao acionar portão:", error);
    throw new HttpsError("internal", "Erro interno ao agendar comando.");
  }
});

/** ============================================================================
 * FUNÇÃO 5: enviarPushNotification
 * ============================================================================ */
exports.enviarPushNotification = onDocumentCreated("notificacoes/{docId}", async (event) => {
  const data = event.data?.data();
  if (!data || !data.sindico_vinculado) return;

  let tokensAlvo = [];

  try {
    if (data.para === "todos") {
      const q = await admin.firestore().collection("usuarios").where("sindico_vinculado", "==", data.sindico_vinculado).get();
      q.forEach(doc => { if (doc.data().fcm_tokens) tokensAlvo.push(...doc.data().fcm_tokens); });
    } else {
      const u = await admin.firestore().collection("usuarios").doc(data.para).get();
      if (u.exists && u.data().fcm_tokens) tokensAlvo.push(...u.data().fcm_tokens);
    }

    if (tokensAlvo.length === 0) return;

    const isPanico = data.titulo && data.titulo.includes("PÂNICO");

    let payload;

    if (isPanico) {
      payload = {
        data: {
          eh_panico: "true",
          title: String(data.titulo || "🚨 ALERTA DE PÂNICO"),
          body: String(data.mensagem || "Verifique as câmeras urgentemente!")
        },
        android: { priority: "high" },
        apns: { 
          payload: { 
            aps: { "content-available": 1 } 
          } 
        }
      };
    } else {
      payload = {
        notification: {
          title: String(data.titulo || "Aviso"),
          body: String(data.mensagem || "")
        },
        data: { 
          eh_panico: "false",
          tipo_acao: String(data.tipo_acao || "acao_avisos"), 
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
        android: { 
          priority: "high",
          notification: { 
            channelId: "logic_home_channel",
            sound: "default",
            defaultSound: true,
            defaultVibrateTimings: true,
            visibility: "public"
          }
        },
        apns: { 
          payload: { 
            aps: { 
              sound: "default",
              badge: 1,
              "content-available": 1,
              "mutable-content": 1
            } 
          } 
        }
      };
    }

    const response = await admin.messaging().sendEachForMulticast({ tokens: tokensAlvo, ...payload });

    await registrarTelemetria(data.sindico_vinculado, 'push_notifications', tokensAlvo.length);

    if (response.failureCount > 0) {
      const tokensAExcluir = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success && (resp.error?.message.includes("not-registered") || resp.error?.message.includes("invalid"))) {
          tokensAExcluir.push(tokensAlvo[idx]);
        }
      });
      if (tokensAExcluir.length > 0 && data.para !== "todos") {
        await admin.firestore().collection("usuarios").doc(data.para).update({
          fcm_tokens: admin.firestore.FieldValue.arrayRemove(...tokensAExcluir)
        });
      }
    }
  } catch (error) {
    console.error("Erro Push:", error);
  }
});

/** ============================================================================
 * FUNÇÃO 6: processarDocumentoOCR
 * ============================================================================ */
exports.processarDocumentoOCR = onCall(async (request) => {
  const data = request.data;
  if (!data.image) return { sucesso: false, erro: "Imagem vazia." };

  if (!request.auth) throw new HttpsError("unauthenticated", "Somente operadores autorizados podem usar o OCR.");
  
  const sindicoEmail = request.auth.token.sindico_vinculado || request.auth.token.email;

  try {
    const vision = require('@google-cloud/vision');
    const client = new vision.ImageAnnotatorClient();

    const [result] = await client.textDetection(Buffer.from(data.image, 'base64'));
    const detections = result.textAnnotations;
    if (!detections || detections.length === 0) return { sucesso: false, erro: "Texto ilegível." };

    const textoExtraido = detections[0].description;
    const textoNormalizado = textoExtraido.toUpperCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    let linhas = textoNormalizado.split('\n').map(l => l.trim()).filter(l => l.length > 0);

    let nomeEncontrado = "";
    let docEncontrado = "";

    const matchCpf = textoNormalizado.match(/\d{3}[\.\s]?\d{3}[\.\s]?\d{3}[\-\s]?\d{2}/);
    const matchRg = textoNormalizado.match(/\d{1,2}[\.\s]?\d{3}[\.\s]?\d{3}[\-\s]?[0-9X]/);

    if (matchCpf) {
      docEncontrado = matchCpf[0].replace(/[^0-9]/g, '');
    } else if (matchRg) {
      docEncontrado = matchRg[0].replace(/[^0-9X]/g, '');
    } else {
      let palavras = textoNormalizado.split(/\s+/);
      let melhorCandidato = "";
      for (let palavra of palavras) {
        if (palavra.includes('/')) continue;
        let soNumeros = palavra.replace(/[^0-9X]/g, '');
        if (soNumeros.length >= 6 && soNumeros.length <= 14 && !/^[X]+$/.test(soNumeros)) {
          if (soNumeros.length > melhorCandidato.length) melhorCandidato = soNumeros;
        }
      }
      if (melhorCandidato) docEncontrado = melhorCandidato;
    }

    let idxNome = -1;
    for (let i = 0; i < linhas.length; i++) {
        let linhaSoLetras = linhas[i].replace(/[^A-Z]/g, ''); 
        if (linhaSoLetras.includes('NOME') && !linhaSoLetras.includes('FILIACAO') && !linhaSoLetras.includes('SOCIAL')) {
            idxNome = i; break;
        }
    }

    const rotulosProibidos = ['FILIACAO', 'PAI', 'MAE', 'NATURALIDADE', 'DATA', 'DOC', 'ORIGEM', 'REGISTRO', 'CPF', 'VALIDADE', 'LOCAL', 'ASSINATURA', 'REPUBLICA', 'FEDERATIVA', 'BRASIL', 'SECRETARIA', 'MINISTERIO', 'SEGURANCA', 'PUBLICA', 'ESTADO', 'POLICIA', 'CIVIL', 'CARTEIRA', 'NACIONAL', 'HABILITACAO', 'IDENTIDADE', 'DETRAN', 'SSP', 'PORTADOR', 'DIRETOR', 'PRESIDENTE', 'NASCIMENTO'];

    if (idxNome !== -1) {
        let linhaDoRolo = linhas[idxNome].replace(/[^A-Z\s]/g, '').replace(/\s+/g, ' ');
        let partes = linhaDoRolo.split('NOME');
        let possivelNome = partes.length > 1 ? partes[1].trim() : "";
        
        if (possivelNome.split(' ').length >= 2) {
            nomeEncontrado = possivelNome;
        } else {
            for (let j = idxNome + 1; j <= idxNome + 3 && j < linhas.length; j++) {
                let linhaCandidata = linhas[j].replace(/[^A-Z\s]/g, '').trim().replace(/\s+/g, ' ');
                let ehRotulo = rotulosProibidos.some(p => linhaCandidata.includes(p));
                if (!ehRotulo && linhaCandidata.split(' ').length >= 2 && linhaCandidata.length > 5) {
                    nomeEncontrado = linhaCandidata; break;
                }
            }
        }
    }

    if (!nomeEncontrado) {
       for (let i = 0; i < linhas.length; i++) {
           let linhaCandidata = linhas[i].replace(/[^A-Z\s]/g, '').trim().replace(/\s+/g, ' ');
           if (linhaCandidata.split(' ').length >= 2 && linhaCandidata.length > 8) {
               let ehGoverno = rotulosProibidos.some(t => linhaCandidata.includes(t));
               if (!ehGoverno) { nomeEncontrado = linhaCandidata; break; }
           }
       }
    }

    await registrarTelemetria(sindicoEmail, 'ocr_vision', 1);

    return { sucesso: true, nome: nomeEncontrado || "NÃO IDENTIFICADO", documento: docEncontrado || "" };

  } catch (error) {
    return { sucesso: false, erro: "Falha de comunicação com o motor de OCR: " + error.message };
  }
});

/** ============================================================================
 * FUNÇÃO 7: salvarFotoVisitante
 * ============================================================================ */
exports.salvarFotoVisitante = onCall(async (request) => {
  const { image, sindico, documento, tokenConvite } = request.data;

  if (!image || !sindico || !documento) throw new HttpsError("invalid-argument", "Dados incompletos.");

  if (tokenConvite) {
    const conviteSnap = await admin.firestore().collection('convites_vip').where('token', '==', tokenConvite).where('status', '==', 'pendente').get();
    if (conviteSnap.empty) throw new HttpsError("permission-denied", "Convite inválido.");
  } else {
    if (!request.auth) throw new HttpsError("unauthenticated", "Acesso negado.");
  }

  try {
    const bucket = admin.storage().bucket();
    const buffer = Buffer.from(image, 'base64');
    const path = `visitantes/${sindico}/${documento}_${Date.now()}.jpg`;
    const file = bucket.file(path);

    await file.save(buffer, { metadata: { contentType: 'image/jpeg' } });
    await registrarTelemetria(sindico, 'fotos_storage', 1);

    return { sucesso: true, url: path };
  } catch (error) {
    throw new HttpsError("internal", "Erro ao salvar a imagem no Storage: " + error.message);
  }
});

/** ============================================================================
 * FUNÇÃO 8: monitorarSessoesAtivas
 * ============================================================================ */
exports.monitorarSessoesAtivas = onDocumentUpdated("usuarios/{email}", async (event) => {
  const dataAntiga = event.data.before.data();
  const dataNova = event.data.after.data();

  const sessoesAntes = dataAntiga.sessoes_ativas || [];
  const sessoesDepois = dataNova.sessoes_ativas || [];

  if (sessoesDepois.length > sessoesAntes.length) {
     let limiteMaximo = 999; 
     if (dataNova.perfil === 'morador') limiteMaximo = 1;
     if (dataNova.perfil === 'porteiro') limiteMaximo = 2; 
     if (dataNova.perfil === 'sindico') limiteMaximo = 3;  

     if (sessoesDepois.length > limiteMaximo && dataNova.uid) {
        try {
           const sessoesPermitidas = sessoesDepois.slice(-limiteMaximo);
           await event.data.after.ref.update({ sessoes_ativas: sessoesPermitidas });
        } catch (e) {
           console.error(`Erro ao atualizar sessões:`, e);
        }
     }
  }
});

/** ============================================================================
 * FUNÇÃO 9: RoboCobradorAsaas (BLINDADO COM AXIOS)
 * ============================================================================ */
exports.gerarCobrancasSaaS = onSchedule({
  schedule: "0 8 * * *", 
  timeZone: "America/Sao_Paulo",
  retryCount: 3,
  secrets: [asaasApiKeySecret]
}, async (event) => {
  console.log("Iniciando varredura diária de vencimentos...");

  const asaasApiKey = asaasApiKeySecret.value();
  const asaasUrl = "https://api.asaas.com/v3"; 

  // Zera as horas para comparar apenas os dias perfeitamente
  const hoje = new Date();
  hoje.setHours(0, 0, 0, 0);

  const limiteVencimento = new Date(hoje);
  limiteVencimento.setDate(hoje.getDate() + 5); 

  try {
    const sindicosSnap = await admin.firestore().collection("usuarios")
      .where("perfil", "==", "sindico")
      .where("servico_ativo", "==", true)
      .get();

    for (let doc of sindicosSnap.docs) {
      const data = doc.data();
      if (!data.data_expiracao) continue;

      const dataExpiracao = data.data_expiracao.toDate();
      const dataExpPura = new Date(dataExpiracao);
      dataExpPura.setHours(0, 0, 0, 0);

      // MÁGICA DE SEGURANÇA: "A data de expiração é menor ou igual a hoje + 5 dias?"
      if (dataExpPura <= limiteVencimento) {
        
        // MÁGICA 2: "Se a fatura JÁ foi gerada e está PENDENTE, pula para o próximo para não duplicar boletos."
        if (data.status_fatura === "PENDENTE" && data.url_fatura_atual) {
          continue; 
        }
        
        let valorDaCobranca = 0;
        let nomeDoPlano = data.plano_id || "Sem Plano";

        if (data.plano_id) {
           const planoDoc = await admin.firestore().collection("planos").doc(data.plano_id).get();
           if (planoDoc.exists && planoDoc.data().valor) {
               valorDaCobranca = parseFloat(planoDoc.data().valor);
           }
        }

        if (valorDaCobranca <= 0) continue; 

        let asaasCustomerId = data.asaas_customer_id;

        // CRIA CLIENTE NO ASAAS COM AXIOS
        if (!asaasCustomerId) {
          try {
            const customerRes = await axios.post(`${asaasUrl}/customers`, {
              name: data.nome,
              email: data.email,
              cpfCnpj: data.cpf_cnpj || "",
              phone: data.telefone || "",
              mobilePhone: data.telefone || "",
              externalReference: data.email 
            }, {
              headers: { "access_token": asaasApiKey, "Content-Type": "application/json" }
            });
            
            if (customerRes.data && customerRes.data.id) {
              asaasCustomerId = customerRes.data.id;
              await doc.ref.update({ asaas_customer_id: asaasCustomerId });
            }
          } catch (e) {
            console.error(`❌ Erro criar cliente Asaas para ${data.email}:`, e?.response?.data || e.message);
            continue;
          }
        }

        // MÁGICA 3: O boleto vence na data EXATA de expiração. Se o robô capturar uma fatura muito atrasada, ele vence no dia atual (O Asaas recusa boletos com data no passado).
        let dataBoleto = new Date(dataExpPura);
        if (dataBoleto < hoje) {
          dataBoleto = new Date(hoje);
        }
        const vencimentoBoleto = dataBoleto.toISOString().split('T')[0]; 
        
        // CRIA FATURA NO ASAAS COM AXIOS
        try {
          const chargeRes = await axios.post(`${asaasUrl}/payments`, {
            customer: asaasCustomerId,
            billingType: "UNDEFINED", 
            value: valorDaCobranca, 
            dueDate: vencimentoBoleto,
            description: `Mensalidade SaaS - Plano ${nomeDoPlano} (${data.condominio})`,
            externalReference: data.email 
          }, {
            headers: { "access_token": asaasApiKey, "Content-Type": "application/json" }
          });

          if (chargeRes.data && chargeRes.data.id) {
            await doc.ref.update({
              url_fatura_atual: chargeRes.data.invoiceUrl,
              status_fatura: "PENDENTE"
            });
            console.log(`✅ Fatura gerada com sucesso para ${data.email}. Vencimento: ${vencimentoBoleto}`);
          }
        } catch (e) {
           console.error(`❌ Erro gerar fatura Asaas para ${data.email}:`, e?.response?.data || e.message);
        }
      }
    }
  } catch (error) {
    console.error("Erro fatal na rotina de cobrança:", error);
  }
});

/** ============================================================================
 * FUNÇÃO 10: CaixaAutomaticoAsaas (Webhook)
 * ============================================================================ */
exports.webhookAsaas = onRequest(async (request, response) => {
  if (request.method !== "POST") return response.status(405).send("Método não permitido");

  let evento = request.body;
  try {
    // Blindagem total contra cofres de dados (Buffers) comuns em webhooks bancários
    if (Buffer.isBuffer(evento)) {
      evento = JSON.parse(evento.toString('utf8'));
    } else if (typeof evento === 'string') {
      evento = JSON.parse(evento);
    } else if (!evento || Object.keys(evento).length === 0) {
      if (request.rawBody) {
        evento = JSON.parse(request.rawBody.toString('utf8'));
      }
    }
  } catch (err) {
    console.error("❌ Erro ao ler pacote do Asaas:", err);
    return response.status(200).send("Pacote ignorado por erro de formatação.");
  }

  console.log(`🔔 Webhook Acionado! Evento capturado: ${evento.event}`);

  if (evento.event === "PAYMENT_RECEIVED" || evento.event === "PAYMENT_CONFIRMED") {
    const paymentData = evento.payment;
    const externalRef = paymentData.externalReference || "";

    if (externalRef.startsWith("FATURAMORADOR|")) {
      const idFatura = externalRef.split("|")[1];
      
      // 1. Dá baixa na fatura do morador
      await admin.firestore().collection("faturas_moradores").doc(idFatura).update({
        status: "RECEIVED",
        data_pagamento: admin.firestore.FieldValue.serverTimestamp()
      });

      // 2. MÁGICA: Identifica se você ganhou a comissão (Split) nesse boleto!
      let valorDaSuaComissao = 0;
      if (paymentData.split && paymentData.split.length > 0) {
         for (let splitItem of paymentData.split) {
            // Soma o valor que foi direcionado para a sua Wallet Master
            valorDaSuaComissao += parseFloat(splitItem.totalValue || splitItem.fixedValue || 0);
         }
      }

      // 3. Se teve comissão, registra na sua "Gaveta" para aparecer no Gráfico Master!
      if (valorDaSuaComissao > 0) {
         await admin.firestore().collection("receitas_saas").add({
           sindico_vinculado: "Tarifa (Fatura Morador)", 
           nome_condominio: "Split de Pagamento Automático",
           valor: valorDaSuaComissao,
           data_pagamento: admin.firestore.FieldValue.serverTimestamp(),
           forma_pagamento: paymentData.billingType || "BOLETO/PIX",
           asaas_payment_id: paymentData.id
         });
      }

      return response.status(200).send("Baixa do morador e comissão registradas.");
    }

    try {
      let docSindicoRef;
      let dadosSindico;

      // MÁGICA: Tenta achar o Síndico direto pelo e-mail dele (externalReference) PRIMEIRO. É infalível!
      if (externalRef && externalRef.includes("@")) {
         const docSnap = await admin.firestore().collection("usuarios").doc(externalRef).get();
         if (docSnap.exists) {
            docSindicoRef = docSnap.ref;
            dadosSindico = docSnap.data();
         }
      }

      // Se por acaso o externalRef falhar, cai pro plano B (Customer ID do Asaas)
      if (!docSindicoRef) {
         const query = await admin.firestore().collection("usuarios").where("asaas_customer_id", "==", paymentData.customer).limit(1).get();
         if (query.empty) {
            console.log("Usuário não encontrado para o Customer:", paymentData.customer);
            return response.status(200).send("Usuário não encontrado.");
         }
         docSindicoRef = query.docs[0].ref;
         dadosSindico = query.docs[0].data();
      }

      let dataAtual = new Date();
      let expiracaoAntiga = dadosSindico.data_expiracao ? dadosSindico.data_expiracao.toDate() : new Date();
      
      let dataBaseParaSoma = (expiracaoAntiga > dataAtual) ? expiracaoAntiga : dataAtual;
      dataBaseParaSoma.setDate(dataBaseParaSoma.getDate() + 30);

      // Limpa a tela de bloqueio do Síndico
      await docSindicoRef.update({
        data_expiracao: admin.firestore.Timestamp.fromDate(dataBaseParaSoma),
        servico_ativo: true,
        status_fatura: "PAGA",
        url_fatura_atual: admin.firestore.FieldValue.delete() 
      });

      // Joga o dinheiro no Gráfico Master
      await admin.firestore().collection("receitas_saas").add({
        sindico_vinculado: externalRef || paymentData.customer,
        nome_condominio: dadosSindico.condominio || "Não informado",
        valor: parseFloat(paymentData.value),
        data_pagamento: admin.firestore.FieldValue.serverTimestamp(),
        forma_pagamento: paymentData.billingType || "DESCONHECIDA",
        asaas_payment_id: paymentData.id
      });

      return response.status(200).send("Renovação SaaS Processada.");
    } catch (erro) {
      console.error("Erro webhook:", erro);
      return response.status(500).send("Erro interno.");
    }
  }
  return response.status(200).send("Ignorado. Evento não reconhecido.");
});

/** ============================================================================
 * FUNÇÃO 11: solicitarAcessoVideo
 * ============================================================================ */
exports.solicitarAcessoVideo = onCall(async (request) => {
  const data = request.data;
  const auth = request.auth;

  if (!auth) throw new HttpsError("unauthenticated", "Você precisa estar logado.");

  const { sindico_alvo, camera_id } = data;
  if (!sindico_alvo || !camera_id) throw new HttpsError("invalid-argument", "Faltam dados.");

  try {
    const userEmail = auth.token.email;
    const userDoc = await admin.firestore().collection("usuarios").doc(userEmail).get();
    if (!userDoc.exists) throw new HttpsError("permission-denied", "Usuário não encontrado.");

    const userData = userDoc.data();
    const temPermissao = (userData.perfil === 'master' || userData.perfil === 'tecnico' || userData.perfil === 'administradora' || userData.sindico_vinculado === sindico_alvo || userEmail === sindico_alvo);

    if (!temPermissao) throw new HttpsError("permission-denied", "Sem permissão para esta câmera.");

    const jwt = require("jsonwebtoken");
    const secretKey = process.env.LOGICHOME_SECRET_JWT;
    if (!secretKey) throw new HttpsError("internal", "Erro de configuração JWT.");

    const ingressoVipJWT = jwt.sign({ action: "read", path: camera_id, user: userEmail }, secretKey, { expiresIn: '5m' });
    return { sucesso: true, jwt: ingressoVipJWT };

  } catch (error) {
    console.error("Erro Video:", error);
    throw new HttpsError("internal", "Erro interno no vídeo.");
  }
});

/** ============================================================================
 * FUNÇÃO 12: obterChaveSeguranca
 * ============================================================================ */
exports.obterChaveSeguranca = onCall((request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Acesso negado.");
  return { sucesso: true, chave: process.env.LOGICHOME_SECRET_KEY || "ChaveTemporariaDe32Caracteres!!!" };
});

/** ============================================================================
 * FUNÇÃO 13: criarSubcontaAdministradora (BLINDADA E OTIMIZADA)
 * ============================================================================ */
exports.criarSubcontaAdministradora = onCall({ secrets: [asaasApiKeySecret] }, async (request) => {
  if (!request.auth) return { sucesso: false, erro: "Acesso negado. Usuário não autenticado." };
  
  const { nome, cpfCnpj, nascimento, tipoEmpresa, email, telefone, cep, endereco, numero, complemento, bairro, faturamento } = request.data;
  const emailAdmin = request.auth.token.email;

  const asaasApiKey = asaasApiKeySecret.value().trim(); 
  const asaasUrl = "https://api.asaas.com/v3"; 

  if (!asaasApiKey) return { sucesso: false, erro: "Erro de configuração no servidor." };

  try {
    const cpfLimpo = (cpfCnpj || "").replace(/\D/g, '');
    const telLimpo = (telefone || "").replace(/\D/g, '');
    const cepLimpo = (cep || "").replace(/\D/g, '');
    
    // Tratamento RIGOROSO para garantir que incomeValue seja um Número e não uma String
    let rendaNumber = 0;
    if (faturamento) {
      rendaNumber = Number(parseFloat(faturamento.toString().replace(',', '.')).toFixed(2));
    }
    if (isNaN(rendaNumber) || rendaNumber <= 0) {
      rendaNumber = 1000.00; // Valor padrão de segurança 
    }

    let birthDateFormatted = "";
    if (nascimento) {
        const parts = nascimento.split('/');
        if (parts.length === 3) {
            birthDateFormatted = `${parts[2]}-${parts[1]}-${parts[0]}`; 
        } else {
            birthDateFormatted = nascimento; 
        }
    }

    // Payload Base (Apenas os CAMPOS UNIVERSAIS exigidos pela API deles)
    const payloadAsaas = {
      name: nome,
      email: email,
      cpfCnpj: cpfLimpo,
      mobilePhone: telLimpo, // Asaas exige mobilePhone
      incomeValue: rendaNumber, // Forçado a ser NUMBER como na documentação
      address: endereco,
      addressNumber: numero,
      province: bairro,
      postalCode: cepLimpo
    };

    // Adicionando os opcionais se existirem
    if (telLimpo) payloadAsaas.phone = telLimpo;
    if (complemento && complemento.trim() !== "") payloadAsaas.complement = complemento.trim();

    // REGRAS ESTRITAS DO ASAAS (PF vs PJ) baseadas na documentação oficial
    if (cpfLimpo.length === 11) {
        // É Pessoa Física (Obrigatório birthDate, NÃO envia companyType)
        if (birthDateFormatted) {
            payloadAsaas.birthDate = birthDateFormatted;
        } else {
            return { sucesso: false, erro: "Data de nascimento é obrigatória para criação de conta Pessoa Física." };
        }
    } else if (cpfLimpo.length === 14) {
        // É Pessoa Jurídica (Obrigatório companyType, NÃO envia birthDate)
        payloadAsaas.companyType = tipoEmpresa || "MEI";
    } else {
        return { sucesso: false, erro: "CPF ou CNPJ com tamanho inválido." };
    }

    console.log("📦 ENVIADO PARA O ASAAS:", JSON.stringify(payloadAsaas, null, 2));

    const response = await axios.post(`${asaasUrl}/accounts`, payloadAsaas, {
      headers: { "access_token": asaasApiKey, "Content-Type": "application/json" }
    });

    const data = response.data;
    
    // MÁGICA: Configura a "Ponte de Comunicação" (Webhook) automaticamente na conta bancária que acabou de nascer!
    try {
      await axios.post(`${asaasUrl}/webhook`, {
        url: "https://us-central1-logichome-a9808.cloudfunctions.net/webhookAsaas",
        email: emailAdmin,
        interrupted: false,
        enabled: true,
        apiVersion: 3,
        events: ["PAYMENT_RECEIVED", "PAYMENT_CONFIRMED"]
      }, {
        headers: { "access_token": data.apiKey, "Content-Type": "application/json" }
      });
    } catch (webhookErr) {
      console.error("Aviso: Subconta criada, mas falhou ao configurar Webhook:", webhookErr?.response?.data || webhookErr.message);
    }

    await admin.firestore().collection("usuarios").doc(emailAdmin).update({
      asaas_wallet_id: data.walletId,
      asaas_api_key: data.apiKey,
      conta_bancaria_criada: true
    });
    
    return { sucesso: true };

  } catch (error) {
    if (error.response && error.response.data) {
      const dataErro = error.response.data;
      console.error("❌ ERRO COMPLETO DO ASAAS:", JSON.stringify(dataErro, null, 2));
      
      let mensagemErro = "O Asaas recusou a requisição.";
      if (dataErro.errors && dataErro.errors.length > 0) {
        mensagemErro = dataErro.errors[0].description; 
      }
      return { sucesso: false, erro: mensagemErro };
    }
    
    console.error("❌ CRASH INTERNO NO NODE:", error.message);
    return { sucesso: false, erro: `Erro interno no servidor: ${error.message}` };
  }
});

/** ============================================================================
 * FUNÇÃO 14: gerarLoteFaturasMoradores (GERENTE / DISPATCHER)
 * OTIMIZADO PARA 10.000+ FATURAS
 * ============================================================================ */
exports.gerarLoteFaturasMoradores = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Acesso negado.");

  const { sindico_vinculado, valor, vencimento, incluir_multas_pendentes } = request.data;
  const emailAdmin = request.auth.token.email;

  const adminDoc = await admin.firestore().collection("usuarios").doc(emailAdmin).get();
  const apiKeyAdmin = adminDoc.data()?.asaas_api_key;

  if (!apiKeyAdmin) throw new HttpsError("failed-precondition", "Administradora não possui conta bancária configurada.");

  try {
    // A MÁGICA 1 (MEMÓRIA): O .select() faz o Firebase trazer APENAS a "capa da pasta" (O ID), sem baixar o peso dos dados.
    const unidadesSnap = await admin.firestore().collection("unidades_base")
      .where("sindico_vinculado", "==", sindico_vinculado)
      .select() 
      .get();

    if (unidadesSnap.empty) {
       throw new HttpsError("failed-precondition", "A Base de Proprietários está vazia. Cadastre as unidades antes de gerar faturas.");
    }

    const { getFunctions } = require("firebase-admin/functions");
    const queue = getFunctions().taskQueue("processarFaturasLoteTask");
    
    const unidadesIds = [];
    unidadesSnap.forEach(doc => unidadesIds.push(doc.id));
    
    const chunkSize = 25;
    let tarefasCriadas = 0;

    for (let i = 0; i < unidadesIds.length; i += chunkSize) {
        const chunk = unidadesIds.slice(i, i + chunkSize);
        
        await queue.enqueue({
            sindico_vinculado,
            valor,
            vencimento,
            incluir_multas_pendentes,
            emailAdmin,
            apiKeyAdmin,
            unidades_ids: chunk
        });
        tarefasCriadas++;
    }

    return { 
        sucesso: true, 
        total: unidadesIds.length, 
        mensagem: `A fábrica iniciou a produção de ${unidadesIds.length} boletos em segundo plano.` 
    };

  } catch (error) {
    if (error instanceof HttpsError) throw error;
    console.error("Erro na geração em lote:", error);
    throw new HttpsError("internal", error.message || "Erro interno ao processar lote.");
  }
});

/** ============================================================================
 * FUNÇÃO 15: processarFaturasLoteTask (O OPERÁRIO / WORKER)
 * BLINDADO COM RATE LIMITS E ANTI-DUPLICAÇÃO
 * ============================================================================ */
exports.processarFaturasLoteTask = onTaskDispatched({
  retryConfig: {
    maxAttempts: 5,
    minBackoffSeconds: 60,
  },
  rateLimits: {
    maxConcurrentDispatches: 10, 
    maxDispatchesPerSecond: 5    
  }
}, async (request) => {
  const { sindico_vinculado, valor, vencimento, incluir_multas_pendentes, emailAdmin, apiKeyAdmin, unidades_ids } = request.data;
  const asaasUrl = "https://api.asaas.com/v3";
  const dataVencimentoFormatada = vencimento.split('T')[0]; 
  const valorBaseFloat = parseFloat(valor);

  // A MÁGICA 3: Leitura rápida (getAll)
  const refs = unidades_ids.map(id => admin.firestore().collection("unidades_base").doc(id));
  const unidadesDocs = await admin.firestore().getAll(...refs);

  for (let unidadeDoc of unidadesDocs) {
      try {
          if (!unidadeDoc.exists) continue;
          const dataUnidade = unidadeDoc.data();

          // A MÁGICA 4: IDEMPOTÊNCIA (ANTI-DUPLICAÇÃO)
          const checkDuplicidade = await admin.firestore().collection("faturas_moradores")
            .where("sindico_vinculado", "==", sindico_vinculado)
            .where("bloco", "==", dataUnidade.bloco)
            .where("ap", "==", dataUnidade.ap)
            .where("vencimento", "==", dataVencimentoFormatada)
            .limit(1)
            .get();

          if (!checkDuplicidade.empty) {
            console.log(`Boleto do Bloco ${dataUnidade.bloco} AP ${dataUnidade.ap} já existe. Pulando (Idempotência).`);
            continue; 
          }

          let valorFinalBoleto = valorBaseFloat;
          let idsCobrancasExtras = [];
          let descricaoFatura = `Taxa Condominial: R$ ${valorBaseFloat.toFixed(2)}`;

          if (incluir_multas_pendentes) {
            const extrasSnap = await admin.firestore().collection("cobrancas_extras")
              .where("sindico_vinculado", "==", sindico_vinculado)
              .where("bloco", "==", dataUnidade.bloco)
              .where("ap", "==", dataUnidade.ap)
              .where("status", "==", "pendente_faturamento")
              .get();

            for (let extraDoc of extrasSnap.docs) {
              const exData = extraDoc.data();
              const v = parseFloat(exData.valor || 0);
              valorFinalBoleto += v;
              idsCobrancasExtras.push(extraDoc.id);
              descricaoFatura += `\n[${exData.tipo.toUpperCase()}] ${exData.titulo}: R$ ${v.toFixed(2)}`;
            }
          }

          if (valorFinalBoleto <= 0) continue; 

          let asaasCustomerId = dataUnidade.asaas_customer_id;

          if (!asaasCustomerId) {
            try {
              const customerRes = await axios.post(`${asaasUrl}/customers`, {
                name: dataUnidade.nome_proprietario,
                email: dataUnidade.email,
                cpfCnpj: (dataUnidade.cpf_cnpj || "").replace(/\D/g, ''),
                phone: (dataUnidade.telefone || "").replace(/\D/g, ''),
                mobilePhone: (dataUnidade.telefone || "").replace(/\D/g, ''),
                externalReference: `UNIDADE|${dataUnidade.bloco}|${dataUnidade.ap}`
              }, { headers: { "access_token": apiKeyAdmin, "Content-Type": "application/json" }});
              
              if (customerRes.data && customerRes.data.id) {
                asaasCustomerId = customerRes.data.id;
                await unidadeDoc.ref.update({ asaas_customer_id: asaasCustomerId });
              }
            } catch (e) { 
              console.error(`Erro criar cliente Asaas para ${dataUnidade.email}:`, e?.response?.data || e.message);
              if (e.response && (e.response.status === 401 || e.response.status === 403)) {
                 await admin.firestore().collection("usuarios").doc(emailAdmin).update({
                    asaas_api_key: admin.firestore.FieldValue.delete(),
                    asaas_wallet_id: admin.firestore.FieldValue.delete(),
                    conta_bancaria_criada: false
                 });
              }
              continue; 
            }
          }

          const faturaRef = admin.firestore().collection('faturas_moradores').doc();

          try {
            const chargeRes = await axios.post(`${asaasUrl}/payments`, {
              customer: asaasCustomerId,
              billingType: "UNDEFINED", 
              value: parseFloat(valorFinalBoleto.toFixed(2)), 
              dueDate: dataVencimentoFormatada,
              description: `Cobrança Condominial (Bloco ${dataUnidade.bloco} - AP ${dataUnidade.ap})\n\n${descricaoFatura}`,
              externalReference: `FATURAMORADOR|${faturaRef.id}`,
              postalService: false,
              split: [
                {
                  walletId: "83ac1dbe-e239-47ee-bb58-01bdaa791574",
                  fixedValue: 1.99 
                }
              ]
            }, { headers: { "access_token": apiKeyAdmin, "Content-Type": "application/json" }});

            if (chargeRes.data && chargeRes.data.id) {
              
              let emailExibicaoApp = dataUnidade.email; 
              const moradorSnap = await admin.firestore().collection("usuarios")
                  .where("sindico_vinculado", "==", sindico_vinculado)
                  .where("perfil", "==", "morador")
                  .where("bloco", "==", dataUnidade.bloco)
                  .where("ap", "==", dataUnidade.ap)
                  .where("status", "==", "aprovado")
                  .limit(1).get();

              if (!moradorSnap.empty) {
                  emailExibicaoApp = moradorSnap.docs[0].id; 
              }

              const batch = admin.firestore().batch();

              batch.set(faturaRef, {
                 sindico_vinculado: sindico_vinculado, 
                 email_morador: emailExibicaoApp, 
                 email_proprietario: dataUnidade.email, 
                 nome_morador: dataUnidade.nome_proprietario, 
                 bloco: dataUnidade.bloco, 
                 ap: dataUnidade.ap, 
                 asaas_payment_id: chargeRes.data.id,
                 valor: valorFinalBoleto, 
                 valor_base: valorBaseFloat, 
                 vencimento: dataVencimentoFormatada,
                 url_fatura: chargeRes.data.invoiceUrl, 
                 status: "PENDING", 
                 data_emissao: admin.firestore.FieldValue.serverTimestamp(),
              });

              if (!moradorSnap.empty) {
                  const notifRef = admin.firestore().collection('notificacoes').doc();
                  batch.set(notifRef, {
                    sindico_vinculado: sindico_vinculado,
                    para: emailExibicaoApp,
                    titulo: '📄 FATURA EMITIDA',
                    mensagem: `A taxa do Bloco ${dataUnidade.bloco} AP ${dataUnidade.ap} foi enviada ao proprietário e está disponível no seu painel para visualização/pagamento.`,
                    data: admin.firestore.FieldValue.serverTimestamp(),
                    remetente: 'Financeiro',
                    tipo_acao: 'acao_avisos'
                  });
              }
              
              if (idsCobrancasExtras.length > 0) {
                for (let idExtra of idsCobrancasExtras) {
                  batch.update(admin.firestore().collection("cobrancas_extras").doc(idExtra), { 
                      status: "faturado", 
                      fatura_vinculada_id: faturaRef.id 
                  });
                }
              }

              await batch.commit();
            }
          } catch (e) { 
              console.error("Erro ao gerar fatura Asaas na Task:", e?.response?.data || e.message);
          }
      } catch (errLoop) {
          console.error("Erro processando unidade individual na Task:", errLoop);
      }
  }
});

/** ============================================================================
 * FUNÇÃO 16: validarLinkVip (SEGURANÇA: Visitante anônimo)
 * ============================================================================ */
exports.validarLinkVip = onCall(async (request) => {
  const { token, documento } = request.data;
  
  if (token) {
    const snap = await admin.firestore().collection('convites_vip')
        .where('token', '==', token)
        .where('status', '==', 'pendente')
        .limit(1).get();

    if (snap.empty) {
      return { sucesso: false, erro: "Este link é inválido ou já foi utilizado." };
    }
    const convite = snap.docs[0].data();
    return { sucesso: true, dadosConvite: convite, idConvite: snap.docs[0].id };
  }
  
  if (documento) {
    const snapHist = await admin.firestore().collection('visitantes_historico').doc(documento).get();
    if (snapHist.exists) {
      return { sucesso: true, historico: snapHist.data() };
    }
    return { sucesso: false };
  }
});

/** ============================================================================
 * FUNÇÃO 17: gerarAcessoVip (SEGURANÇA: Visitante anônimo)
 * ============================================================================ */
exports.gerarAcessoVip = onCall(async (request) => {
  const data = request.data;
  const { idConvite, dadosVip, historicoVip, documento } = data;

  if (!idConvite || !dadosVip || !documento) {
    throw new HttpsError("invalid-argument", "Dados incompletos.");
  }

  try {
    // 1. Confere novamente se o convite ainda é válido (Double Check anti-hacker)
    const refConvite = admin.firestore().collection('convites_vip').doc(idConvite);
    const docConvite = await refConvite.get();
    if (!docConvite.exists || docConvite.data().status !== 'pendente') {
      throw new HttpsError("permission-denied", "Convite já utilizado.");
    }

    const batch = admin.firestore().batch();

    // 2. Salva Histórico
    const refHistorico = admin.firestore().collection('visitantes_historico').doc(documento);
    batch.set(refHistorico, {
      ...historicoVip,
      ultima_visita: admin.firestore.FieldValue.serverTimestamp()
    });

    // 3. Salva Acesso VIP
    const refAcesso = admin.firestore().collection('acessos_vip').doc();
    const codigoVip = Math.floor(100000 + Math.random() * 900000).toString();
    
    batch.set(refAcesso, {
      ...dadosVip,
      codigo: codigoVip,
      status: 'valido',
      data_criacao: admin.firestore.FieldValue.serverTimestamp()
    });

    // 4. Queima o convite para ninguém usar o mesmo link duas vezes
    batch.update(refConvite, { status: 'utilizado' });

    await batch.commit();

    return { sucesso: true, codigoGerado: codigoVip };
  } catch (error) {
    console.error("Erro gerar VIP:", error);
    throw new HttpsError("internal", "Erro ao gerar o código VIP.");
  }
});

/** ============================================================================
 * FUNÇÃO 18: completarCadastroMorador (SEGURANÇA: Fim do Ghost Login)
 * ============================================================================ */
exports.completarCadastroMorador = onCall(async (request) => {
  const { email, cpf, data_nascimento, tipo_ocupacao, foto_base64, sindico } = request.data;
  
  if (!email || !foto_base64 || !sindico) {
    return { sucesso: false, erro: "Dados incompletos." };
  }

  try {
    const userRef = admin.firestore().collection('usuarios').doc(email);
    const userDoc = await userRef.get();

    // Trava de Segurança: Só atualiza se o morador acabou de ser criado e está pendente
    if (!userDoc.exists || userDoc.data().status !== 'pendente') {
      throw new HttpsError("permission-denied", "Operação bloqueada. Usuário não pendente.");
    }

    // Grava a foto diretamente pelo servidor (Poderes de Admin)
    const bucket = admin.storage().bucket();
    const buffer = Buffer.from(foto_base64, 'base64');
    const path = `biometria/${sindico}/${email}.jpg`;
    const file = bucket.file(path);
    
    await file.save(buffer, { metadata: { contentType: 'image/jpeg' } });
    
    const fotoUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media`;

    // Conclui a injeção do CPF e da Foto
    await userRef.update({
      cpf: cpf || '',
      data_nascimento: data_nascimento || '',
      tipo_ocupacao: tipo_ocupacao || '',
      foto_storage_url: fotoUrl,
      sincronizado_catraca: false
    });

    return { sucesso: true };
  } catch (error) {
    console.error("Erro ao completar cadastro:", error);
    throw new HttpsError("internal", "Falha interna ao concluir cadastro.");
  }
});