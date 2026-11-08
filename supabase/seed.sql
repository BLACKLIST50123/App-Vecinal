-- =====================================================================
-- App Vecinal — Datos de demostración (Chimbote / Nuevo Chimbote)
-- Ejecutar DESPUÉS de schema.sql. Teléfonos ficticios (999 000 xxx).
-- Para reiniciar la demo: vuelve a ejecutar este archivo.
-- =====================================================================

delete from public.vistos_buenos where autor_id is null;
delete from public.servicios     where autor_id is null;
delete from public.publicaciones where autor_id is null and origen = 'app';

-- ---------------- Módulo 1 · Directorio de oficios (día a día) -------
insert into public.servicios
  (autor_nombre, categoria, titulo, descripcion, precio_ref, telefono, horario, sector, lat, lng, created_at)
values
 ('Don Julio Ramírez','gasfiteria','Gasfitero a domicilio','Arreglo fugas, caños, termas y desatoros. 20 años trabajando en el barrio.','Desde S/ 30','999 000 101','Lun a Sáb, 7 am a 7 pm','Miraflores Alto',-9.0651,-78.5801, now() - interval '20 days'),
 ('Rosa Paredes','costura','Costura y arreglos de ropa','Bastas, cierres, uniformes escolares y polos de promoción.','Desde S/ 5','999 000 102','Lun a Vie, 9 am a 6 pm','Casco Urbano',-9.0752,-78.5928, now() - interval '18 days'),
 ('Luis Electricista','electricidad','Electricista con experiencia','Instalaciones, tableros y cortocircuitos. Atiendo urgencias.','Desde S/ 40','999 000 103','Todos los días','La Florida',-9.0820,-78.5770, now() - interval '15 days'),
 ('Carpintería Huamán','carpinteria','Carpintería y muebles a medida','Puertas, roperos, cocinas y reparación de muebles.','Según trabajo','999 000 104','Lun a Sáb','El Progreso',-9.0566,-78.5705, now() - interval '14 days'),
 ('Toño Cerrajero','cerrajeria','Cerrajero 24 horas','Apertura de puertas, cambio de chapas y copias de llaves.','Desde S/ 25','999 000 105','24 horas','21 de Abril',-9.0866,-78.5826, now() - interval '12 days'),
 ('Profe Carmen','clases','Clases de matemática y comunicación','Refuerzo escolar para primaria y secundaria, en casa o virtual.','S/ 15 la hora','999 000 106','Tardes','Buenos Aires',-9.1262,-78.5262, now() - interval '10 days'),
 ('Kevin Paseos','mascotas','Paseador y cuidador de mascotas','Paseos de 1 hora y cuidado por días cuando viajas.','S/ 10 el paseo','999 000 107','Mañanas y tardes','Bellamar',-9.1175,-78.5425, now() - interval '9 days'),
 ('Maestro Pedro','albanileria','Albañil: techos y tarrajeo','Construcción, tarrajeo e impermeabilización de techos antes de lluvias.','Según obra','999 000 108','Lun a Sáb','Villa María',-9.0985,-78.5695, now() - interval '8 days'),
 ('TecnoAyuda Ana','tecnologia','Reparación de celulares y computadoras','Cambio de pantalla, formateo e instalación de programas.','Desde S/ 20','999 000 109','Lun a Sáb, 10 am a 8 pm','Casco Urbano',-9.0740,-78.5945, now() - interval '6 days'),
 ('Enf. Lucía Torres','salud','Enfermera a domicilio','Inyectables, curaciones y control de presión arterial.','Desde S/ 15','999 000 110','Previa cita','San Pedro',-9.0485,-78.5855, now() - interval '5 days'),
 ('Doña Juana','comida','Menú casero y viandas','Menú del día, delivery dentro del sector.','S/ 10','999 000 111','12 pm a 3 pm','Miraflores Alto',-9.0660,-78.5790, now() - interval '3 days'),
 ('Jorge Técnico','gasfiteria','Instalación de tanques y bombas de agua','Tanques elevados, bombas y cisternas.','Desde S/ 50','999 000 112','Lun a Sáb','Nicolás Garatea',-9.1335,-78.5155, now() - interval '2 days'),
 -- Productos del barrio
 ('Panadería La Espiga','panaderia','Pan de yema y pan francés recién horneado','Salida de pan a las 6 am y 5 pm. Tortas por encargo.','S/ 0.20 c/u','999 000 113','6 am a 9 pm','El Progreso',-9.0575,-78.5698, now() - interval '7 days'),
 ('Bodega Don Lucho','bodega','Bodega con delivery en el sector','Abarrotes, gas y agua de mesa. Te lo llevo a tu casa sin recargo.','Precio de mercado','999 000 114','7 am a 11 pm','La Florida',-9.0818,-78.5768, now() - interval '11 days'),
 ('Manos Chimbotanas','artesania','Artesanía y recuerdos hechos en el barrio','Tejidos, bisutería y adornos con conchitas de playa.','Desde S/ 8','999 000 115','Sábados y domingos','Casco Urbano',-9.0738,-78.5950, now() - interval '4 days'),
 ('Feria de la Sra. Nely','segunda_mano','Ropa, útiles y juguetes de segunda mano','Todo en buen estado y a precio de remate.','Desde S/ 2','999 000 116','Domingos 8 am a 1 pm','Bellamar',-9.1172,-78.5440, now() - interval '1 day');

-- ---------------- Módulo 1 · Grupos de apoyo (emergencia) -------------
insert into public.servicios
  (autor_nombre, autor_rol, categoria, titulo, descripcion, telefono, horario, sector, lat, lng, es_emergencia)
values
 ('Brigada Vecinal Chimbote','organizacion','salud','Brigada vecinal de primeros auxilios','Voluntarios capacitados en primeros auxilios y traslado de heridos leves.','999 000 201','24 horas durante la emergencia','Casco Urbano',-9.0758,-78.5920, true),
 ('Olla Común Villa María','organizacion','alimentos','Olla común Villa María','Desayuno y almuerzo para familias afectadas. Trae tu táper.','999 000 202','7 am a 2 pm','Villa María',-9.0992,-78.5688, true),
 ('Junta Vecinal Bellamar','organizacion','albergue','Albergue temporal: local comunal Bellamar','Capacidad para 40 personas. Colchones, frazadas y baños.','999 000 203','24 horas','Bellamar',-9.1182,-78.5415, true),
 ('Rescatistas del Barrio','organizacion','rescate','Rescatistas voluntarios','Apoyo para evacuar a personas con movilidad reducida.','999 000 204','24 horas','La Florida',-9.0812,-78.5762, true),
 ('Escucha Solidaria','organizacion','psicologico','Escucha solidaria: apoyo emocional','Psicólogos voluntarios por llamada o en el albergue.','999 000 205','8 am a 10 pm','Buenos Aires',-9.1255,-78.5270, true);

-- ---------------- Visto Bueno Vecinal (recomendaciones) ---------------
insert into public.vistos_buenos (servicio_id, autor_nombre, comentario, autor_verificado)
select s.id, v.nombre, v.comentario, true
from (values
  ('Pan de yema y pan francés recién horneado','Rocío T.','El pan sale calientito, el mejor del sector.'),
  ('Pan de yema y pan francés recién horneado','Manuel A.',null),
  ('Pan de yema y pan francés recién horneado','Kelly P.','Hace tortas riquísimas por encargo.'),
  ('Bodega con delivery en el sector','Antonio R.','Me trajo el gas en 10 minutos.'),
  ('Bodega con delivery en el sector','Lourdes M.',null),
  ('Artesanía y recuerdos hechos en el barrio','Valeria C.','Lindos recuerdos para regalar.'),
  ('Gasfitero a domicilio','María L.','Llegó puntual y cobró lo justo.'),
  ('Gasfitero a domicilio','Carlos P.','Arregló la fuga de mi cocina en 20 minutos.'),
  ('Gasfitero a domicilio','Elena R.','Muy honrado, lo recomiendo.'),
  ('Gasfitero a domicilio','Jorge V.',null),
  ('Gasfitero a domicilio','Sonia M.','Vino un domingo por una emergencia.'),
  ('Electricista con experiencia','Rosa T.','Me revisó todo el tablero, muy seguro.'),
  ('Electricista con experiencia','Miguel A.',null),
  ('Electricista con experiencia','Patty G.','Explica todo con paciencia.'),
  ('Electricista con experiencia','Raúl C.',null),
  ('Cerrajero 24 horas','Lucho F.','Me salvó a las 2 am.'),
  ('Cerrajero 24 horas','Diana S.',null),
  ('Cerrajero 24 horas','Martín Q.','Rápido y amable.'),
  ('Clases de matemática y comunicación','Gaby H.','Mi hijo subió sus notas.'),
  ('Clases de matemática y comunicación','Andrea P.','Muy paciente con los niños.'),
  ('Clases de matemática y comunicación','Fiorella R.',null),
  ('Clases de matemática y comunicación','Jaime L.',null),
  ('Clases de matemática y comunicación','Nora C.','La mejor del barrio.'),
  ('Clases de matemática y comunicación','Oscar D.',null),
  ('Enfermera a domicilio','Teresa V.','Cuida a mi mamá cada semana, excelente.'),
  ('Enfermera a domicilio','Hugo B.',null),
  ('Enfermera a domicilio','Carmen Z.','Muy profesional.'),
  ('Carpintería y muebles a medida','Iván M.','Mi ropero quedó perfecto.'),
  ('Carpintería y muebles a medida','Liz A.',null),
  ('Costura y arreglos de ropa','Mónica E.','Arregla uniformes rapidísimo.'),
  ('Costura y arreglos de ropa','Pilar N.',null),
  ('Menú casero y viandas','Beto R.','Sazón de casa, porciones grandes.'),
  ('Menú casero y viandas','Julia K.',null),
  ('Menú casero y viandas','Renzo P.',null),
  ('Paseador y cuidador de mascotas','Vale S.','Mi perro lo adora.'),
  ('Reparación de celulares y computadoras','Kike T.','Cambió mi pantalla el mismo día.'),
  ('Albañil: techos y tarrajeo','Doris L.','Impermeabilizó mi techo antes de las lluvias.'),
  ('Albañil: techos y tarrajeo','Félix C.',null),
  ('Brigada vecinal de primeros auxilios','Junta Bellamar','Atendieron a 30 vecinos en 2023.'),
  ('Olla común Villa María','Señora Elsa','Nos dieron de comer toda la semana.'),
  ('Albergue temporal: local comunal Bellamar','Familia Ríos','Nos recibieron cuando se inundó la casa.')
) as v(titulo, nombre, comentario)
join public.servicios s on s.titulo = v.titulo and s.autor_id is null;

-- ---------------- Módulo 2 · Cadena de Favores (día a día) ------------
insert into public.publicaciones
  (autor_nombre, tipo, categoria, titulo, descripcion, contacto_nombre, contacto_telefono, sector, lat, lng, created_at)
values
 ('Alberto S.','ofrezco','herramientas','Presto mi taladro y escalera','Me los devuelves el mismo día. Paso por tu casa si es cerca.','Alberto','999 000 301','Miraflores Alto',-9.0645,-78.5810, now() - interval '3 hours'),
 ('Gladys M.','pido','movilidad','Necesito movilidad al Hospital La Caleta el jueves','Mi mamá tiene cita a las 8 am y no puede caminar mucho.','Gladys','999 000 302','Casco Urbano',-9.0760,-78.5915, now() - interval '5 hours'),
 ('Joaquín R.','ofrezco','habilidad','Enseño a usar el celular a adultos mayores','WhatsApp, videollamadas y Yape. Sábados por la mañana.','Joaquín','999 000 303','El Progreso',-9.0570,-78.5715, now() - interval '1 day'),
 ('Marleny C.','pido','donacion','Busco útiles escolares para mi hijo','Cuadernos y colores para 3er grado.','Marleny','999 000 304','Villa María',-9.0978,-78.5701, now() - interval '1 day'),
 ('Familia Ugaz','ofrezco','donacion','Regalo ropa de niño (talla 6 a 8)','Dos bolsas en buen estado.','Sra. Ugaz','999 000 305','Bellamar',-9.1170,-78.5432, now() - interval '2 days'),
 ('Rafael T.','pido','ayuda','Ayuda para cargar muebles el sábado','Me mudo dentro del mismo sector, invito el almuerzo.','Rafael','999 000 306','La Florida',-9.0826,-78.5752, now() - interval '2 days'),
 ('Sofía L.','ofrezco','habilidad','Cambio clases de guitarra por clases de inglés','Nivel básico, 1 hora por semana.','Sofía','999 000 307','Buenos Aires',-9.1268,-78.5248, now() - interval '3 days'),
 ('Wilmer P.','pido','herramientas','¿Alguien me presta una carretilla?','Para sacar desmonte, solo por una tarde.','Wilmer','999 000 308','Nicolás Garatea',-9.1330,-78.5160, now() - interval '4 days'),
 ('Hija de la Sra. Rosa','pido','cuidado','Acompañar a mi mamá a su cita del jueves','Tiene 78 años y va al centro de salud a las 9 am. Yo trabajo ese día.','Lucía','999 000 309','Miraflores Alto',-9.0648,-78.5806, now() - interval '6 hours'),
 ('Don Carlos','ofrezco','cuidado','Puedo hacer compras a adultos mayores del sector','Voy al mercado los martes y viernes. Avísame qué necesitas.','Carlos','999 000 310','Villa María',-9.0986,-78.5698, now() - interval '1 day');

-- ---------------- Colectas del barrio (responsabilidad social) --------
insert into public.publicaciones
  (autor_nombre, autor_rol, tipo, categoria, titulo, descripcion, contacto_nombre, contacto_telefono, meta, avance, sector, lat, lng, created_at)
values
 ('Parroquia San Pedro','organizacion','pido','colecta','Útiles escolares para 30 niños de Villa María','Cuadernos, lápices y colores. Puedes dejarlos en la parroquia de 9 am a 6 pm.','Hna. Carmen','999 000 311',30,18,'Villa María',-9.0991,-78.5690, now() - interval '2 days'),
 ('Junta Vecinal Bellamar','organizacion','pido','colecta','Frazadas para adultos mayores antes del invierno','Nuevas o en buen estado. Las recogemos en tu casa.','Sr. Ruiz','999 000 312',40,11,'Bellamar',-9.1178,-78.5418, now() - interval '3 days');

-- ---------------- Módulo 2 · Tablero humanitario (emergencia) ---------
insert into public.publicaciones
  (autor_nombre, tipo, categoria, titulo, descripcion, contacto_nombre, contacto_telefono, personas, prioridad, es_emergencia, sector, lat, lng, created_at)
values
 ('Vecina Mz. C','pido','vulnerable','Señora de 82 años vive sola y no tiene agua','Mz. C Lt. 4. No puede caminar; su hija vive en Lima.','Vecina Mz. C','999 000 401',1,'critica',true,'Villa María',-9.0995,-78.5682, now() - interval '40 minutes'),
 ('Familia Castro','pido','albergue','Casa inundada, necesitamos dónde dormir','Somos 4, con un bebé de 8 meses.','Pedro Castro','999 000 402',4,'critica',true,'Casco Urbano',-9.0745,-78.5940, now() - interval '1 hour'),
 ('Familia Rojas','pido','agua_alimento','Familia de 5 sin agua potable','Desde ayer no llega el agua al sector.','Ana Rojas','999 000 403',5,'alta',true,'Bellamar',-9.1188,-78.5410, now() - interval '2 hours'),
 ('Jhon E.','pido','salud','Necesito insulina para mi papá','La farmacia del barrio está cerrada.','Jhon','999 000 404',1,'alta',true,'El Progreso',-9.0558,-78.5722, now() - interval '3 hours'),
 ('Bodega Don Lucho','ofrezco','recurso','Tengo 20 bidones de agua para repartir','Pasen por la bodega con su DNI, uno por familia.','Don Lucho','999 000 405',null,'normal',true,'La Florida',-9.0818,-78.5768, now() - interval '90 minutes'),
 ('Sra. Mercedes','ofrezco','albergue','Ofrezco mi segundo piso para 2 familias','Tiene baño y está seco.','Mercedes','999 000 406',null,'normal',true,'Miraflores Alto',-9.0655,-78.5795, now() - interval '4 hours');

-- Algunos pedidos ya verificados por una organización (para la demo).
update public.publicaciones set verificada = true
 where autor_id is null and titulo in (
   'Casa inundada, necesitamos dónde dormir',
   'Tengo 20 bidones de agua para repartir');

-- Emergencia apagada al inicio. El moderador la activa desde la app.
update public.emergencia
   set activa = false,
       titulo = 'Lluvias intensas e inundaciones',
       mensaje = 'Hay calles inundadas en Chimbote. Si necesitas ayuda, toca NECESITO AYUDA. Si no tienes internet, guarda tu pedido y compártelo por QR.',
       actualizado_en = now()
 where id = 1;

-- ---------------- Recomendaciones de la misma zona (migración 0016) ----
-- Los vecinos de demo recomiendan servicios de su propio sector, con los
-- motivos que se deducen de su comentario.
update public.vistos_buenos vb
   set autor_sector = s.sector,
       motivos = coalesce(nullif(array_remove(array[
         case when vb.comentario ilike any (array['%puntual%', '%rápid%', '%minutos%', '%2 am%', '%domingo%']) then 'puntual' end,
         case when vb.comentario ilike '%justo%' then 'precio_justo' end,
         case when vb.comentario ilike any (array['%amable%', '%pacien%', '%cuida%']) then 'amable' end,
         case when vb.comentario ilike any (array['%honrad%', '%seguro%', '%profesional%']) then 'confiable' end,
         case when vb.comentario ilike any (array['%mejor%', '%perfecto%', '%excelente%', '%arregl%', '%rico%', '%riquísim%', '%sazón%', '%notas%'])
              or vb.comentario is null then 'buen_trabajo' end
       ], null), '{}'), array['buen_trabajo'])
  from public.servicios s
 where s.id = vb.servicio_id and vb.autor_id is null;
