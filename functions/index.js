const functions = require("firebase-functions");
const admin = require("firebase-admin");
const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

admin.initializeApp();

exports.revisarEquiposPendientes = functions.pubsub.schedule("every 5 minutes").onRun(async (context) => {
  const ahora = admin.firestore.Timestamp.now();
  const equiposRef = admin.firestore().collection("equipos");
  const snapshot = await equiposRef.where("estado", "==", "Pendiente").get();

  if (snapshot.empty) {
    console.log("No hay equipos pendientes para revisar.");
    return null;
  }

  const batch = admin.firestore().batch();
  snapshot.forEach((doc) => {
    const data = doc.data();
    const timestampSolicitud = data.timestamp_solicitud;

    if (timestampSolicitud) {
      const minutosPasados = (ahora.toMillis() - timestampSolicitud.toMillis()) / 60000;
      if (minutosPasados > 15) {
        // Si han pasado más de 15 minutos
        batch.update(doc.ref, { estado: "Disponible" });
        console.log(`Equipo ${doc.id} liberado automáticamente.`);
      }
    }
  });

  await batch.commit();
  console.log("Proceso de liberación automática completado.");
  return null;
});