const functions = require("firebase-functions");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();

// Cloud Function para crear estudiantes (llamada por gestores)
exports.crearEstudiante = functions.https.onRequest(async (req, res) => {
  // Configurar CORS
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Método no permitido' });
    return;
  }

  try {
    const { nombre, dni, email, celular, password, gestorUid } = req.body;

    // Validar que todos los campos requeridos estén presentes
    if (!nombre || !dni || !email || !celular || !password || !gestorUid) {
      res.status(400).json({ 
        error: 'Todos los campos son requeridos',
        campos: { nombre, dni, email, celular, password: password ? 'presente' : 'faltante', gestorUid }
      });
      return;
    }

    // Verificar que el gestor existe y tiene rol de gestor
    const gestorDoc = await admin.firestore().collection('usuarios').doc(gestorUid).get();
    if (!gestorDoc.exists) {
      res.status(403).json({ error: 'Gestor no encontrado' });
      return;
    }

    const gestorData = gestorDoc.data();
    if (gestorData.rol !== 'gestor') {
      res.status(403).json({ error: 'No tienes permisos para crear estudiantes' });
      return;
    }

    // Verificar si el email ya existe
    try {
      const existingUser = await admin.auth().getUserByEmail(email);
      if (existingUser) {
        res.status(409).json({ error: 'El correo ya está registrado' });
        return;
      }
    } catch (error) {
      // Si el error es 'user-not-found', significa que el email no existe, lo cual está bien
      if (error.code !== 'auth/user-not-found') {
        throw error;
      }
    }

    // Crear el usuario en Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: email,
      password: password,
      displayName: nombre,
    });

    // Guardar datos en Firestore
    await admin.firestore().collection('usuarios').doc(userRecord.uid).set({
      'TipoUser': "Buen Usuario",
      'acepto_terminos': true,
      'celular': celular,
      'dni': dni,
      'email': email,
      'nombre': nombre,
      'puntos': 10,
      'rol': "estudiante",
      'uid': userRecord.uid,
      'creado_por': gestorUid,
      'fecha_creacion': admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Estudiante creado exitosamente: ${userRecord.uid} por gestor: ${gestorUid}`);

    res.status(201).json({
      success: true,
      uid: userRecord.uid,
      message: 'Estudiante creado exitosamente'
    });

  } catch (error) {
    logger.error('Error al crear estudiante:', error);
    
    if (error.code === 'auth/email-already-exists') {
      res.status(409).json({ error: 'El correo ya está registrado' });
    } else if (error.code === 'auth/invalid-email') {
      res.status(400).json({ error: 'El correo no es válido' });
    } else if (error.code === 'auth/weak-password') {
      res.status(400).json({ error: 'La contraseña es muy débil' });
    } else {
      res.status(500).json({ error: 'Error interno del servidor' });
    }
  }
});

// exports.revisarEquiposPendientes = functions.pubsub.schedule("every 5 minutes").onRun(async (context) => {
//   const ahora = admin.firestore.Timestamp.now();
//   const equiposRef = admin.firestore().collection("equipos");
//   const snapshot = await equiposRef.where("estado", "==", "Pendiente").get();
//
//   if (snapshot.empty) {
//     console.log("No hay equipos pendientes para revisar.");
//     return null;
//   }
//
//   const batch = admin.firestore().batch();
//   snapshot.forEach((doc) => {
//     const data = doc.data();
//     const timestampSolicitud = data.timestamp_solicitud;
//
//     if (timestampSolicitud) {
//       const minutosPasados = (ahora.toMillis() - timestampSolicitud.toMillis()) / 60000;
//       if (minutosPasados > 15) {
//         // Si han pasado más de 15 minutos
//         batch.update(doc.ref, { estado: "Disponible" });
//         console.log(`Equipo ${doc.id} liberado automáticamente.`);
//       }
//     }
//   });
//
//   await batch.commit();
//   console.log("Proceso de liberación automática completado.");
//   return null;
// });