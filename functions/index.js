const functions = require("firebase-functions");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");
const nodemailer = require("nodemailer");

admin.initializeApp();

// NOTA: La función crearEstudiante ya está desplegada como gen 2, 
// por lo que está comentada aquí para evitar conflictos.
// exports.crearEstudiante = functions.https.onRequest(async (req, res) => {
//   ... código original comentado ...
// });

// Cloud Function para enviar correo de confirmación cuando se crea una solicitud
exports.enviarCorreoConfirmacion = functions.firestore
  .document('solicitudes/{solicitudId}')
  .onCreate(async (snap, context) => {
    const solicitud = snap.data();
    
    try {
      // Configurar el transporte de correo (Gmail)
      const transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: {
          user: 'kenss12345@gmail.com',
          pass: 'qsex cejw glnq namr' // Contraseña de aplicación de Gmail
        }
      });

      // Construir contenido de equipos
      const contenidoEquipos = solicitud.equipos
        .map(e => `- ${e.nombre} (${e.estado_prestamo})`)
        .join('\n');

      // Construir contenido de integrantes
      const contenidoIntegrantes = solicitud.integrantes && solicitud.integrantes.length > 0
        ? solicitud.integrantes.map((dni, index) => `${index + 1}. ${dni}`).join('\n')
        : 'No especificado';

      // Formatear fecha de devolución
      const fechaDevolucion = solicitud.fecha_devolucion && solicitud.fecha_devolucion.toDate 
        ? solicitud.fecha_devolucion.toDate().toLocaleDateString('es-PE')
        : 'N/A';

      // Configurar el mensaje
      const mailOptions = {
        from: '"Soporte Audiovisual" <kenss12345@gmail.com>',
        to: solicitud.email,
        subject: 'Confirmación de solicitud de préstamo',
        text: `
Hola ${solicitud.nombre},

Tu solicitud de préstamo ha sido registrada con éxito.

Detalles de tu solicitud:
- Fecha de entrega: ${solicitud.fecha_prestamo}
- Fecha de devolución: ${fechaDevolucion}
- Asignatura: ${solicitud.asignatura || ''}
- Curso: ${solicitud.curso || ''}
- Docente: ${solicitud.docente || ''}
- Nombre de grupo: ${solicitud.nombre_grupo || ''}
- Semestre: ${solicitud.semestre || ''}
- NRC: ${solicitud.nrc || ''}
- Cantidad de integrantes: ${solicitud.cantidad_integrantes || 0}
- Integrantes:
${contenidoIntegrantes}
- Lugar de Trabajo: ${solicitud.lugar || ''}
- Trabajo a Realizar: ${solicitud.trabajo || ''}

Equipos solicitados:
${contenidoEquipos}

Gracias por usar nuestro sistema.

Atentamente,
Soporte Audiovisual
      `,
        html: `
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
<h2 style="color: #f97316;">Confirmación de solicitud de préstamo</h2>

<p>Hola <strong>${solicitud.nombre}</strong>,</p>

<p>Tu solicitud de préstamo ha sido registrada con éxito.</p>

<h3 style="color: #f97316;">Detalles de tu solicitud:</h3>
<table style="width: 100%; border-collapse: collapse;">
  <tr style="background-color: #f3f4f6;">
    <td style="padding: 8px; border: 1px solid #e5e7eb;"><strong>Fecha de entrega:</strong></td>
    <td style="padding: 8px; border: 1px solid #e5e7eb;">${solicitud.fecha_prestamo}</td>
  </tr>
  <tr>
    <td style="padding: 8px; border: 1px solid #e5e7eb;"><strong>Fecha de devolución:</strong></td>
    <td style="padding: 8px; border: 1px solid #e5e7eb;">${fechaDevolucion}</td>
  </tr>
  <tr style="background-color: #f3f4f6;">
    <td style="padding: 8px; border: 1px solid #e5e7eb;"><strong>Asignatura:</strong></td>
    <td style="padding: 8px; border: 1px solid #e5e7eb;">${solicitud.asignatura || ''}</td>
  </tr>
  <tr>
    <td style="padding: 8px; border: 1px solid #e5e7eb;"><strong>Curso:</strong></td>
    <td style="padding: 8px; border: 1px solid #e5e7eb;">${solicitud.curso || ''}</td>
  </tr>
  <tr style="background-color: #f3f4f6;">
    <td style="padding: 8px; border: 1px solid #e5e7eb;"><strong>Docente:</strong></td>
    <td style="padding: 8px; border: 1px solid #e5e7eb;">${solicitud.docente || ''}</td>
  </tr>
  <tr>
    <td style="padding: 8px; border: 1px solid #e5e7eb;"><strong>Nombre de grupo:</strong></td>
    <td style="padding: 8px; border: 1px solid #e5e7eb;">${solicitud.nombre_grupo || ''}</td>
  </tr>
  <tr style="background-color: #f3f4f6;">
    <td style="padding: 8px; border: 1px solid #e5e7eb;"><strong>Semestre:</strong></td>
    <td style="padding: 8px; border: 1px solid #e5e7eb;">${solicitud.semestre || ''}</td>
  </tr>
  <tr>
    <td style="padding: 8px; border: 1px solid #e5e7eb;"><strong>NRC:</strong></td>
    <td style="padding: 8px; border: 1px solid #e5e7eb;">${solicitud.nrc || ''}</td>
  </tr>
  <tr style="background-color: #f3f4f6;">
    <td style="padding: 8px; border: 1px solid #e5e7eb;"><strong>Cantidad de integrantes:</strong></td>
    <td style="padding: 8px; border: 1px solid #e5e7eb;">${solicitud.cantidad_integrantes || 0}</td>
  </tr>
  <tr>
    <td style="padding: 8px; border: 1px solid #e5e7eb;"><strong>Lugar de Trabajo:</strong></td>
    <td style="padding: 8px; border: 1px solid #e5e7eb;">${solicitud.lugar || ''}</td>
  </tr>
</table>

<h3 style="color: #f97316; margin-top: 20px;">Integrantes:</h3>
<pre style="background-color: #f3f4f6; padding: 10px; border-radius: 5px;">${contenidoIntegrantes}</pre>

<h3 style="color: #f97316;">Equipos solicitados:</h3>
<ul style="list-style: none; padding: 0;">
  ${solicitud.equipos.map(e => `<li style="padding: 5px; background-color: #fff7ed; margin: 5px 0; border-left: 3px solid #f97316; padding-left: 10px;">📹 ${e.nombre} (${e.estado_prestamo})</li>`).join('')}
</ul>

<p style="margin-top: 20px;">Gracias por usar nuestro sistema.</p>

<p style="color: #6b7280;">Atentamente,<br><strong>Soporte Audiovisual</strong></p>
</div>
      `
      };

      // Enviar el correo
      const info = await transporter.sendMail(mailOptions);
      
      logger.info('Correo enviado exitosamente:', info.messageId);
      logger.info('Para:', solicitud.email);
      
      return null;
    } catch (error) {
      logger.error('Error al enviar correo:', error);
      // No lanzamos el error para que la función no falle
      return null;
    }
  });