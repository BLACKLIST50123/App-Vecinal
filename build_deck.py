import os
import pptx
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE

def create_presentation():
    prs = pptx.Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6] # blank layout

    # Color Palette definitions
    NAVY_DEEP = RGBColor(15, 23, 42)      # #0F172A
    NAVY_CARD = RGBColor(30, 41, 59)      # #1E293B
    CANVAS_LIGHT = RGBColor(250, 248, 245)# #FAF8F5
    WHITE = RGBColor(255, 255, 255)
    ORANGE_ACCENT = RGBColor(232, 149, 107)# #E8956B
    ORANGE_DEEP = RGBColor(169, 83, 43)   # #A9532B
    ORANGE_LIGHT = RGBColor(254, 243, 235)# Soft orange card fill
    RED_ALERT = RGBColor(229, 57, 53)     # #E53935
    RED_SOFT = RGBColor(253, 236, 234)    # #FDECEA
    GREEN_VERIFIED = RGBColor(46, 125, 50)# #2E7D32
    GREEN_SOFT = RGBColor(232, 245, 233)
    TEXT_MAIN = RGBColor(30, 41, 59)      # #1E293B
    TEXT_MUTED = RGBColor(91, 101, 119)   # #5B6577
    TEXT_LIGHT = RGBColor(241, 245, 249)  # #F1F5F9
    BORDER_LIGHT = RGBColor(226, 232, 240)# #E2E8F0
    BORDER_DARK = RGBColor(51, 65, 85)    # #334155

    logo_path = os.path.abspath("assets/images/logo_icono.png")
    media_dir = os.path.abspath("extracted_media/ppt/media")

    def add_bg(slide, color):
        bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
        bg.fill.solid()
        bg.fill.fore_color.rgb = color
        bg.line.fill.background()
        return bg

    def add_header(slide, tag_text, title_text, dark=False, speaker=None):
        # Category pill / Tag
        tag_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.45), Inches(8.0), Inches(0.35))
        tf_tag = tag_box.text_frame
        tf_tag.word_wrap = True
        tf_tag.margin_left = tf_tag.margin_top = tf_tag.margin_right = tf_tag.margin_bottom = 0
        p_tag = tf_tag.paragraphs[0]
        p_tag.text = tag_text.upper()
        p_tag.font.name = "Arial"
        p_tag.font.size = Pt(10.5)
        p_tag.font.bold = True
        p_tag.font.color.rgb = ORANGE_ACCENT if dark else ORANGE_DEEP

        # Speaker tag on the right if provided
        if speaker:
            sp_box = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(9.8), Inches(0.42), Inches(2.7), Inches(0.38))
            sp_box.fill.solid()
            sp_box.fill.fore_color.rgb = NAVY_CARD if dark else WHITE
            sp_box.line.color.rgb = BORDER_DARK if dark else BORDER_LIGHT
            sp_box.line.width = Pt(1)
            tf_sp = sp_box.text_frame
            tf_sp.vertical_anchor = MSO_ANCHOR.MIDDLE
            tf_sp.margin_left = tf_sp.margin_right = Inches(0.1)
            p_sp = tf_sp.paragraphs[0]
            p_sp.text = f"🎙️ {speaker}"
            p_sp.font.name = "Arial"
            p_sp.font.size = Pt(9.5)
            p_sp.font.bold = True
            p_sp.font.color.rgb = TEXT_LIGHT if dark else TEXT_MAIN
            p_sp.alignment = PP_ALIGN.CENTER

        # Main Title
        title_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.85), Inches(11.7), Inches(0.75))
        tf_title = title_box.text_frame
        tf_title.word_wrap = True
        tf_title.margin_left = tf_title.margin_top = tf_title.margin_right = tf_title.margin_bottom = 0
        p_title = tf_title.paragraphs[0]
        p_title.text = title_text
        p_title.font.name = "Arial"
        p_title.font.size = Pt(22)
        p_title.font.bold = True
        p_title.font.color.rgb = WHITE if dark else TEXT_MAIN

    # =========================================================================
    # SLIDE 1: PORTADA (High Impact Navy)
    # =========================================================================
    s1 = prs.slides.add_slide(blank_layout)
    add_bg(s1, NAVY_DEEP)

    # Accent decorative bar
    bar = s1.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.8), Inches(1.2), Inches(0.12), Inches(4.8))
    bar.fill.solid()
    bar.fill.fore_color.rgb = ORANGE_ACCENT
    bar.line.fill.background()

    # Content Left Box
    c_box = s1.shapes.add_textbox(Inches(1.2), Inches(1.2), Inches(7.5), Inches(4.8))
    tf1 = c_box.text_frame
    tf1.word_wrap = True
    tf1.margin_left = tf1.margin_top = tf1.margin_right = tf1.margin_bottom = 0

    p_badge = tf1.paragraphs[0]
    p_badge.text = "HACKATHON UTP 2026 · PITCH DECK FINAL"
    p_badge.font.name = "Arial"
    p_badge.font.size = Pt(11)
    p_badge.font.bold = True
    p_badge.font.color.rgb = ORANGE_ACCENT
    p_badge.space_after = Pt(12)

    p_main = tf1.add_paragraph()
    p_main.text = "Conecta Vecino"
    p_main.font.name = "Arial"
    p_main.font.size = Pt(44)
    p_main.font.bold = True
    p_main.font.color.rgb = WHITE
    p_main.space_after = Pt(8)

    p_sub = tf1.add_paragraph()
    p_sub.text = '"Tu barrio te respalda, con o sin internet."'
    p_sub.font.name = "Georgia"
    p_sub.font.size = Pt(20)
    p_sub.font.italic = True
    p_sub.font.color.rgb = ORANGE_ACCENT
    p_sub.space_after = Pt(24)

    p_desc = tf1.add_paragraph()
    p_desc.text = "Red vecinal hiperlocal de proximidad, favores solidarios y comando humanitario ante desastres con transmisión resiliente por Mula QR."
    p_desc.font.name = "Arial"
    p_desc.font.size = Pt(13)
    p_desc.font.color.rgb = RGBColor(203, 213, 225)
    p_desc.space_after = Pt(36)

    # Team members badge list
    p_team_hdr = tf1.add_paragraph()
    p_team_hdr.text = "EQUIPO ALPHACODERS:"
    p_team_hdr.font.name = "Arial"
    p_team_hdr.font.size = Pt(10)
    p_team_hdr.font.bold = True
    p_team_hdr.font.color.rgb = TEXT_MUTED

    p_team = tf1.add_paragraph()
    p_team.text = "Madeley Panta (Líder)  ·  Ana (Propuesta)  ·  Erick (Backend)  ·  Bradley Rodriguez (Demo)  ·  Eduardo (Impacto)"
    p_team.font.name = "Arial"
    p_team.font.size = Pt(11)
    p_team.font.color.rgb = WHITE

    # Right Card: App Mockup Preview & Logo
    r_card = s1.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(9.0), Inches(1.2), Inches(3.5), Inches(5.1))
    r_card.fill.solid()
    r_card.fill.fore_color.rgb = NAVY_CARD
    r_card.line.color.rgb = BORDER_DARK
    r_card.line.width = Pt(1.5)

    if os.path.exists(logo_path):
        s1.shapes.add_picture(logo_path, Inches(10.25), Inches(1.6), width=Inches(1.0))

    img_hero = os.path.join(media_dir, "image6.jpeg")
    if os.path.exists(img_hero):
        s1.shapes.add_picture(img_hero, Inches(9.35), Inches(2.8), width=Inches(2.8), height=Inches(3.2))

    # =========================================================================
    # SLIDE 2: EL CONTEXTO REAL (Chimbote & La Paradoja Digital)
    # =========================================================================
    s2 = prs.slides.add_slide(blank_layout)
    add_bg(s2, CANVAS_LIGHT)
    add_header(s2, "01 / Contexto y Diagnóstico", "Chimbote no es San Isidro: la desconexión del barrio", dark=False, speaker="Madeley Panta (0:00 - 1:15)")

    # Left Narrative Card
    left_card = s2.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(1.75), Inches(5.5), Inches(5.1))
    left_card.fill.solid()
    left_card.fill.fore_color.rgb = WHITE
    left_card.line.color.rgb = BORDER_LIGHT
    left_card.line.width = Pt(1)

    tf_lc = left_card.text_frame
    tf_lc.word_wrap = True
    tf_lc.margin_left = tf_lc.margin_right = Inches(0.4)
    tf_lc.margin_top = Inches(0.4)

    p_lc0 = tf_lc.paragraphs[0]
    p_lc0.text = "LA HISTORIA DE DOÑA ROSA (68 AÑOS)"
    p_lc0.font.name = "Arial"
    p_lc0.font.size = Pt(11)
    p_lc0.font.bold = True
    p_lc0.font.color.rgb = ORANGE_DEEP
    p_lc0.space_after = Pt(12)

    p_lc1 = tf_lc.add_paragraph()
    p_lc1.text = "Doña Rosa vive en Bellamar (Nuevo Chimbote). Ayer se le rompió una tubería en la cocina.\n\n" \
                 "• No entra a buscar a Google ni descarga apps complejas en inglés.\n" \
                 "• No confía en los letreros pegados en postes por temor a robos o estafas.\n" \
                 "• Pasa 3 horas llamando parientes y preguntando puerta a puerta si conocen a 'un gasfitero honrado'."
    p_lc1.font.name = "Arial"
    p_lc1.font.size = Pt(12.5)
    p_lc1.font.color.rgb = TEXT_MAIN
    p_lc1.space_after = Pt(16)

    p_lc2 = tf_lc.add_paragraph()
    p_lc2.text = "A dos cuadras de su casa, Don Carlos es gasfitero con 15 años de oficio intachable, pero hoy no tiene trabajo porque no tiene vitrina. El barrio está desconectado."
    p_lc2.font.name = "Georgia"
    p_lc2.font.size = Pt(12)
    p_lc2.font.italic = True
    p_lc2.font.color.rgb = TEXT_MUTED

    # Right Stats 3 Cards
    stat_data = [
        ("95.9%", "Hogares con Smartphone (INEI)", "La penetración móvil es casi total, pero el 35.5% no tiene internet fijo en el hogar. La conectividad es frágil y prepago."),
        ("11,493", "Emergencias Registradas en 2025 (INDECI)", "Inundaciones, huaicos, lluvias y sismos. En Áncash, ante lluvias intensas las antenas celulares y la fibra óptica colapsan con frecuencia."),
        ("3 Horas", "Tiempo promedio para hallar ayuda cercana", "La falta de canales confiables obliga al boca a boca manual o a quedar a merced de la desinformación en redes sociales.")
    ]

    for idx, (num, title_stat, desc_stat) in enumerate(stat_data):
        sc = s2.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(6.6), Inches(1.75 + idx * 1.75), Inches(5.9), Inches(1.55))
        sc.fill.solid()
        sc.fill.fore_color.rgb = WHITE
        sc.line.color.rgb = BORDER_LIGHT
        sc.line.width = Pt(1)

        tf_sc = sc.text_frame
        tf_sc.word_wrap = True
        tf_sc.margin_left = Inches(0.35)
        tf_sc.margin_top = Inches(0.25)
        tf_sc.margin_right = Inches(0.3)

        p_num = tf_sc.paragraphs[0]
        p_num.text = num
        p_num.font.name = "Arial"
        p_num.font.size = Pt(24)
        p_num.font.bold = True
        p_num.font.color.rgb = ORANGE_DEEP if idx != 1 else RED_ALERT
        p_num.space_after = Pt(2)

        p_st = tf_sc.add_paragraph()
        p_st.text = title_stat
        p_st.font.name = "Arial"
        p_st.font.size = Pt(11)
        p_st.font.bold = True
        p_st.font.color.rgb = TEXT_MAIN

        p_sd = tf_sc.add_paragraph()
        p_sd.text = desc_stat
        p_sd.font.name = "Arial"
        p_sd.font.size = Pt(9.5)
        p_sd.font.color.rgb = TEXT_MUTED

    # =========================================================================
    # SLIDE 3: LOS 3 DOLORES DEL BARRIO (Problema)
    # =========================================================================
    s3 = prs.slides.add_slide(blank_layout)
    add_bg(s3, CANVAS_LIGHT)
    add_header(s3, "02 / El Problema", "Por qué los grupos de WhatsApp y Facebook no resuelven esto", dark=False, speaker="Madeley Panta (1:15 - 2:00)")

    pains = [
        ("DOLOR 01", "La Ruleta de la Desconfianza", "Buscar un oficio en grupos de Facebook con 50,000 miembros es peligroso.",
         "• Reseñas falsas y perfiles anónimos.\n• Nadie respalda la honestidad o tarifas del prestador.\n• El adulto mayor es víctima frecuente de cobros abusivos o robos.\n• Los buenos trabajadores del barrio siguen invisibles.", ORANGE_DEEP),
        ("DOLOR 02", "Recursos Ociosos Sin Canal", "La solidaridad del barrio no fluye porque no existe un canal directo.",
         "• Un vecino tiene una escalera o una carretilla guardada.\n• Otro vecino necesita reparar su techo urgentemente.\n• Pedir ayuda cara a cara da vergüenza o desconfianza.\n• Los favores y la ayuda mutua comunitaria quedan bloqueados.", NAVY_CARD),
        ("DOLOR 03", "El Colapso en Desastres", "Cuando llega la emergencia, las herramientas convencionales mueren.",
         "• La red celular se satura o se corta la fibra.\n• Los chats se inundan de cadenas de pánico y fake news.\n• Defensa Civil no sabe quién necesita medicina o rescate primero.\n• Los adultos mayores y personas con discapacidad quedan aislados.", RED_ALERT)
    ]

    for idx, (tag_p, title_p, sub_p, bullets_p, col_acc) in enumerate(pains):
        card_p = s3.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8 + idx * 3.98), Inches(1.75), Inches(3.75), Inches(5.1))
        card_p.fill.solid()
        card_p.fill.fore_color.rgb = WHITE
        card_p.line.color.rgb = BORDER_LIGHT
        card_p.line.width = Pt(1)

        # Top color accent stripe inside the card
        strp = s3.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8 + idx * 3.98), Inches(1.75), Inches(3.75), Inches(0.12))
        strp.fill.solid()
        strp.fill.fore_color.rgb = col_acc
        strp.line.fill.background()

        tf_p = card_p.text_frame
        tf_p.word_wrap = True
        tf_p.margin_left = tf_p.margin_right = Inches(0.3)
        tf_p.margin_top = Inches(0.35)

        p0 = tf_p.paragraphs[0]
        p0.text = tag_p
        p0.font.name = "Arial"
        p0.font.size = Pt(10)
        p0.font.bold = True
        p0.font.color.rgb = col_acc
        p0.space_after = Pt(4)

        p1 = tf_p.add_paragraph()
        p1.text = title_p
        p1.font.name = "Arial"
        p1.font.size = Pt(15)
        p1.font.bold = True
        p1.font.color.rgb = TEXT_MAIN
        p1.space_after = Pt(8)

        p2 = tf_p.add_paragraph()
        p2.text = sub_p
        p2.font.name = "Georgia"
        p2.font.size = Pt(10.5)
        p2.font.italic = True
        p2.font.color.rgb = TEXT_MUTED
        p2.space_after = Pt(16)

        p3 = tf_p.add_paragraph()
        p3.text = bullets_p
        p3.font.name = "Arial"
        p3.font.size = Pt(11)
        p3.font.color.rgb = TEXT_MAIN

    # =========================================================================
    # SLIDE 4: LA SOLUCIÓN: 2 MÓDULOS × 2 MODOS
    # =========================================================================
    s4 = prs.slides.add_slide(blank_layout)
    add_bg(s4, CANVAS_LIGHT)
    add_header(s4, "03 / Propuesta de Valor", "Conecta Vecino: 2 Módulos integrados × 2 Modos de operación", dark=False, speaker="Ana (2:00 - 3:00)")

    # Left Column: Modo Cotidiano
    mc_box = s4.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(1.75), Inches(5.75), Inches(5.1))
    mc_box.fill.solid()
    mc_box.fill.fore_color.rgb = WHITE
    mc_box.line.color.rgb = BORDER_LIGHT
    mc_box.line.width = Pt(1)

    tf_mc = mc_box.text_frame
    tf_mc.word_wrap = True
    tf_mc.margin_left = tf_mc.margin_right = Inches(0.35)
    tf_mc.margin_top = Inches(0.3)

    pm0 = tf_mc.paragraphs[0]
    pm0.text = "MODO COTIDIANO (DÍA A DÍA)"
    pm0.font.name = "Arial"
    pm0.font.size = Pt(11)
    pm0.font.bold = True
    pm0.font.color.rgb = ORANGE_DEEP
    pm0.space_after = Pt(6)

    pm1 = tf_mc.add_paragraph()
    pm1.text = "1. Servicios con Visto Bueno Vecinal"
    pm1.font.name = "Arial"
    pm1.font.size = Pt(15)
    pm1.font.bold = True
    pm1.font.color.rgb = TEXT_MAIN
    pm1.space_after = Pt(4)

    pm2 = tf_mc.add_paragraph()
    pm2.text = "Directorio local de gasfiteros, electricistas, bodegas y talleres ordenados por distancia métrica. Los Vistos Buenos son de vecinos verificados por GPS (1 voto por persona, autovoto bloqueado por BD)."
    pm2.font.name = "Arial"
    pm2.font.size = Pt(10.5)
    pm2.font.color.rgb = TEXT_MUTED
    pm2.space_after = Pt(14)

    pm3 = tf_mc.add_paragraph()
    pm3.text = "2. Red de Favores Solidarios (Sin Dinero)"
    pm3.font.name = "Arial"
    pm3.font.size = Pt(15)
    pm3.font.bold = True
    pm3.font.color.rgb = TEXT_MAIN
    pm3.space_after = Pt(4)

    pm4 = tf_mc.add_paragraph()
    pm4.text = "Préstamos de herramientas, acompañamiento médico y ayuda comunitaria. 'Yo ayudo' en 1 clic. Cero transacciones monetarias por diseño: pura reciprocidad de barrio."
    pm4.font.name = "Arial"
    pm4.font.size = Pt(10.5)
    pm4.font.color.rgb = TEXT_MUTED

    # Right Column: Modo Emergencia
    me_box = s4.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(6.8), Inches(1.75), Inches(5.75), Inches(5.1))
    me_box.fill.solid()
    me_box.fill.fore_color.rgb = WHITE
    me_box.line.color.rgb = RED_ALERT
    me_box.line.width = Pt(1.5)

    tf_me = me_box.text_frame
    tf_me.word_wrap = True
    tf_me.margin_left = tf_me.margin_right = Inches(0.35)
    tf_me.margin_top = Inches(0.3)

    pme0 = tf_me.paragraphs[0]
    pme0.text = "MODO EMERGENCIA (DESASTRES & SISMOS)"
    pme0.font.name = "Arial"
    pme0.font.size = Pt(11)
    pme0.font.bold = True
    pme0.font.color.rgb = RED_ALERT
    pme0.space_after = Pt(6)

    pme1 = tf_me.add_paragraph()
    pme1.text = "El Interruptor que Transforma la App"
    pme1.font.name = "Arial"
    pme1.font.size = Pt(15)
    pme1.font.bold = True
    pme1.font.color.rgb = TEXT_MAIN
    pme1.space_after = Pt(4)

    pme2 = tf_me.add_paragraph()
    pme2.text = "Activado por la Junta Vecinal o automáticamente ante alerta del COEN/USGS. Toda la app cambia a pantalla roja de alto contraste para visibilidad en humo o apagones."
    pme2.font.name = "Arial"
    pme2.font.size = Pt(10.5)
    pme2.font.color.rgb = TEXT_MUTED
    pme2.space_after = Pt(14)

    pme3 = tf_me.add_paragraph()
    pme3.text = "Tablero Humanitario & Botón SOS"
    pme3.font.name = "Arial"
    pme3.font.size = Pt(15)
    pme3.font.bold = True
    pme3.font.color.rgb = TEXT_MAIN
    pme3.space_after = Pt(4)

    pme4 = tf_me.add_paragraph()
    pme4.text = "• Botón SOS físico con teclas de volumen (funciona con pantalla bloqueada).\n• Solicitud de auxilio sin necesidad de crear cuenta previa.\n• Clasificación inmediata por urgencia: Médica, Rescate o Víveres.\n• Marcación rápida 116 (Bomberos), 105 (Policía), 106 (SAMU)."
    pme4.font.name = "Arial"
    pme4.font.size = Pt(10.5)
    pme4.font.color.rgb = TEXT_MUTED

    # =========================================================================
    # SLIDE 5: DIFERENCIADOR CLAVE: MULA DE DATOS QR
    # =========================================================================
    s5 = prs.slides.add_slide(blank_layout)
    add_bg(s5, NAVY_DEEP)
    add_header(s5, "04 / Innovación Radical", "Mula de Datos QR: La ayuda viaja cuando internet se cae", dark=True, speaker="Ana (3:00 - 4:00)")

    # 4 Steps Horizontal Flow
    steps = [
        ("01", "Zona Sin Señal", "El vecino genera su alerta SOS ('Agua potable y camilla'). Al no haber red, la app la firma localmente con ID único y genera un QR de alta densidad."),
        ("02", "La Mula Humana", "Un vecino, brigadista o mototaxista que se desplaza fuera del barrio abre 'Llevar mensajes' y escanea el QR en 2 segundos desde su cámara."),
        ("03", "Conexión Recuperada", "Al llegar a una zona con señal 4G o WiFi, el teléfono de la 'mula' sube el paquete a Supabase automáticamente en segundo plano."),
        ("04", "Tablero del Barrio", "El reporte aparece en el mapa y panel de emergencias con la insignia 'LLEGÓ POR QR', listo para despacho por Bomberos o Serenazgo.")
    ]

    for idx, (num_s, title_s, desc_s) in enumerate(steps):
        st_box = s5.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8 + idx * 2.98), Inches(1.85), Inches(2.78), Inches(4.0))
        st_box.fill.solid()
        st_box.fill.fore_color.rgb = NAVY_CARD
        st_box.line.color.rgb = ORANGE_ACCENT if idx in [1, 3] else BORDER_DARK
        st_box.line.width = Pt(1.5)

        tf_s = st_box.text_frame
        tf_s.word_wrap = True
        tf_s.margin_left = tf_s.margin_right = Inches(0.25)
        tf_s.margin_top = Inches(0.3)

        ps0 = tf_s.paragraphs[0]
        ps0.text = num_s
        ps0.font.name = "Arial"
        ps0.font.size = Pt(28)
        ps0.font.bold = True
        ps0.font.color.rgb = ORANGE_ACCENT
        ps0.space_after = Pt(4)

        ps1 = tf_s.add_paragraph()
        ps1.text = title_s
        ps1.font.name = "Arial"
        ps1.font.size = Pt(14)
        ps1.font.bold = True
        ps1.font.color.rgb = WHITE
        ps1.space_after = Pt(12)

        ps2 = tf_s.add_paragraph()
        ps2.text = desc_s
        ps2.font.name = "Arial"
        ps2.font.size = Pt(10.5)
        ps2.font.color.rgb = RGBColor(203, 213, 225)

    # Bottom Quote Pill
    quote_bar = s5.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(6.1), Inches(11.7), Inches(0.8))
    quote_bar.fill.solid()
    quote_bar.fill.fore_color.rgb = RGBColor(24, 34, 53)
    quote_bar.line.color.rgb = ORANGE_ACCENT
    quote_bar.line.width = Pt(1)

    tf_qb = quote_bar.text_frame
    tf_qb.vertical_anchor = MSO_ANCHOR.MIDDLE
    tf_qb.margin_left = Inches(0.4)
    pq = tf_qb.paragraphs[0]
    pq.text = '💡 "La información viaja de persona a persona a pie o en mototaxi cuando las torres caen. Ningún vecino queda incomunicado."'
    pq.font.name = "Georgia"
    pq.font.size = Pt(12)
    pq.font.italic = True
    pq.font.color.rgb = WHITE

    # =========================================================================
    # SLIDE 6: ACCESIBILIDAD RADICAL (Adultos Mayores & Cero Fricción)
    # =========================================================================
    s6 = prs.slides.add_slide(blank_layout)
    add_bg(s6, CANVAS_LIGHT)
    add_header(s6, "05 / Inclusión Real", "Accesibilidad Radical: Diseñado para Doña Rosa, no para Silicon Valley", dark=False, speaker="Ana (4:00 - 4:45)")

    features = [
        ("PUBLICAR POR VOZ NATIVO", "Hablar en vez de escribir",
         "Reconocimiento de voz directo en el hardware del teléfono (Speech-to-Text nativo). Costo cero: no consume APIs de pago ni necesita internet para transcribir el pedido.", ORANGE_DEEP),
        ("TEXTO A VOZ (BOTÓN ESCUCHAR)", "Para vecinos con baja visión",
         "Un botón grande reproduce el título y detalle de cualquier publicación en voz alta, garantizando que vecinos analfabetos o con problemas visuales no queden fuera.", NAVY_CARD),
        ("LETRAS A / A+ / A++ Y ALTO CONTRASTE", "Tipografía legible embebida",
         "Fuentes Atkinson Hyperlegible incluidas dentro del paquete de la app (no requiere conexión para descargarlas). Cumplimiento de contraste WCAG AA 5:1.", GREEN_VERIFIED),
        ("FLUJO EN 3 TOQUES REALES", "Cero burocracia de registro",
         "1. Tocar '+ Publicar'\n2. Dictar o elegir categoría\n3. Confirmar 'Publicar ahora'\nSin correos de validación ni contraseñas olvidadas: registro por número móvil.", RED_ALERT)
    ]

    for idx, (tag_f, title_f, desc_f, col_f) in enumerate(features):
        x = Inches(0.8 + (idx % 2) * 5.95)
        y = Inches(1.85 + (idx // 2) * 2.5)

        fb = s6.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, y, Inches(5.65), Inches(2.25))
        fb.fill.solid()
        fb.fill.fore_color.rgb = WHITE
        fb.line.color.rgb = BORDER_LIGHT
        fb.line.width = Pt(1)

        # left vertical badge
        v_bar = s6.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, y, Inches(0.12), Inches(2.25))
        v_bar.fill.solid()
        v_bar.fill.fore_color.rgb = col_f
        v_bar.line.fill.background()

        tf_fb = fb.text_frame
        tf_fb.word_wrap = True
        tf_fb.margin_left = Inches(0.35)
        tf_fb.margin_top = Inches(0.2)
        tf_fb.margin_right = Inches(0.3)

        pf0 = tf_fb.paragraphs[0]
        pf0.text = tag_f
        pf0.font.name = "Arial"
        pf0.font.size = Pt(10)
        pf0.font.bold = True
        pf0.font.color.rgb = col_f
        pf0.space_after = Pt(3)

        pf1 = tf_fb.add_paragraph()
        pf1.text = title_f
        pf1.font.name = "Arial"
        pf1.font.size = Pt(14)
        pf1.font.bold = True
        pf1.font.color.rgb = TEXT_MAIN
        pf1.space_after = Pt(6)

        pf2 = tf_fb.add_paragraph()
        pf2.text = desc_f
        pf2.font.name = "Arial"
        pf2.font.size = Pt(10.5)
        pf2.font.color.rgb = TEXT_MUTED

    # =========================================================================
    # SLIDE 7: DEMOSTRACIÓN EN VIVO (3 MINUTOS MVP)
    # =========================================================================
    s7 = prs.slides.add_slide(blank_layout)
    add_bg(s7, CANVAS_LIGHT)
    add_header(s7, "06 / Validación Técnica", "Demostración en Vivo: 3 minutos de MVP funcional en el Honor", dark=False, speaker="Bradley Rodriguez (4:45 - 5:45)")

    demo_steps = [
        ("0:00", "Servicios & Visto Bueno", "Entrar como Doña Rosa, buscar 'Gasfitería', validar sus 5 Vistos Buenos verificados y botón directo de Llamar / WhatsApp."),
        ("0:45", "Publicación por Voz", "Tocar botón de micrófono: 'Necesito una escalera para podar un árbol'. El formulario se llena solo y se publica en 3 toques."),
        ("1:20", "Inclusión en Vivo", "Cambiar tamaño de fuente a A++ en el perfil y presionar botón 'Escuchar' para oír la publicación leída en voz alta."),
        ("1:50", "Activación Modo SOS", "La Junta Vecinal enciende el Modo Emergencia: la interfaz se vuelve roja de alto contraste para el barrio entero."),
        ("2:25", "Mula QR Sin Señal", "Simular 'Modo Avión' -> Enviar pedido de auxilio -> Generar código QR -> Segundo teléfono escanea y lo sincroniza con éxito.")
    ]

    for idx, (time_d, title_d, desc_d) in enumerate(demo_steps):
        db = s7.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(1.75 + idx * 1.02), Inches(7.5), Inches(0.92))
        db.fill.solid()
        db.fill.fore_color.rgb = WHITE
        db.line.color.rgb = BORDER_LIGHT
        db.line.width = Pt(1)

        tf_db = db.text_frame
        tf_db.word_wrap = True
        tf_db.margin_left = Inches(0.2)
        tf_db.margin_top = Inches(0.12)
        tf_db.margin_right = Inches(0.2)

        pd0 = tf_db.paragraphs[0]
        pd0.text = f"{time_d}  ·  {title_d}"
        pd0.font.name = "Arial"
        pd0.font.size = Pt(12)
        pd0.font.bold = True
        pd0.font.color.rgb = ORANGE_DEEP if idx < 3 else RED_ALERT

        pd1 = tf_db.add_paragraph()
        pd1.text = desc_d
        pd1.font.name = "Arial"
        pd1.font.size = Pt(9.5)
        pd1.font.color.rgb = TEXT_MUTED

    # Right Side Live Mockup Container
    r_mc = s7.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(8.6), Inches(1.75), Inches(3.9), Inches(5.1))
    r_mc.fill.solid()
    r_mc.fill.fore_color.rgb = NAVY_CARD
    r_mc.line.color.rgb = BORDER_DARK
    r_mc.line.width = Pt(1)

    tf_rm = r_mc.text_frame
    tf_rm.word_wrap = True
    tf_rm.margin_left = tf_rm.margin_right = Inches(0.3)
    tf_rm.margin_top = Inches(0.3)

    prm0 = tf_rm.paragraphs[0]
    prm0.text = "HARDWARE REAL DE PRUEBA"
    prm0.font.name = "Arial"
    prm0.font.size = Pt(10.5)
    prm0.font.bold = True
    prm0.font.color.rgb = ORANGE_ACCENT
    prm0.space_after = Pt(4)

    prm1 = tf_rm.add_paragraph()
    prm1.text = "Honor X6a · Android 13\n" \
                "• 0 caídas en 10 pruebas unitarias de Flutter.\n" \
                "• Cámara calibrada para escaneo de QR en 1.2 segundos.\n" \
                "• Atajo físico con botones de volumen probado.\n" \
                "• Plan B: Video demostrativo 1080p precargado por seguridad."
    prm1.font.name = "Arial"
    prm1.font.size = Pt(11)
    prm1.font.color.rgb = WHITE
    prm1.space_after = Pt(16)

    img_demo = os.path.join(media_dir, "image10.jpeg")
    if os.path.exists(img_demo):
        s7.shapes.add_picture(img_demo, Inches(9.2), Inches(3.6), width=Inches(2.7), height=Inches(3.0))

    # =========================================================================
    # SLIDE 8: ARQUITECTURA TÉCNICA & ESCALABILIDAD
    # =========================================================================
    s8 = prs.slides.add_slide(blank_layout)
    add_bg(s8, CANVAS_LIGHT)
    add_header(s8, "07 / Arquitectura & Stack", "Tecnología robusta, abierta y con costo de operación S/ 0", dark=False, speaker="Erick (5:45 - 6:20)")

    stack_cards = [
        ("FRONTEND MULTIPLATAFORMA", "Flutter (Dart)",
         "• Código único compilado para Android nativo y Web responsiva.\n"
         "• Animaciones fluidas a 60 FPS con flutter_animate.\n"
         "• Offline-first con base de datos local SQLite y colas de sincronización.", ORANGE_DEEP),
        ("BASE DE DATOS & SEGURIDAD", "Supabase (PostgreSQL)",
         "• Autenticación celular sin fricción.\n"
         "• Row Level Security (RLS) mandatorio: las reglas de permisos viven en el motor Postgres, no en la app.\n"
         "• Constraints de BD para impedir autovotos y votos duplicados.", NAVY_CARD),
        ("GEOLOCALIZACIÓN LIBRE", "OpenStreetMap (OSM)",
         "• Mapas vectoriales sin costo por consulta (cero dependencia de facturación de Google Maps API).\n"
         "• Cálculo de distancia métrica por coordenadas Haversine directamente en el dispositivo.", GREEN_VERIFIED),
        ("ALERTAS SÍSMICAS AUTOMÁTICAS", "USGS API & Edge Functions",
         "• Monitoreo de sismos en tiempo real conectado al servicio geológico de EE. UU. (USGS).\n"
         "• Detección automática de epicentros en la costa ancashina para pre-alerta de tsunamis o réplicas.", RED_ALERT)
    ]

    for idx, (tag_t, title_t, desc_t, col_t) in enumerate(stack_cards):
        x = Inches(0.8 + (idx % 2) * 5.95)
        y = Inches(1.85 + (idx // 2) * 2.5)

        tb = s8.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, y, Inches(5.65), Inches(2.25))
        tb.fill.solid()
        tb.fill.fore_color.rgb = WHITE
        tb.line.color.rgb = BORDER_LIGHT
        tb.line.width = Pt(1)

        v_t = s8.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, y, Inches(0.12), Inches(2.25))
        v_t.fill.solid()
        v_t.fill.fore_color.rgb = col_t
        v_t.line.fill.background()

        tf_tb = tb.text_frame
        tf_tb.word_wrap = True
        tf_tb.margin_left = Inches(0.35)
        tf_tb.margin_top = Inches(0.2)
        tf_tb.margin_right = Inches(0.3)

        pt0 = tf_tb.paragraphs[0]
        pt0.text = tag_t
        pt0.font.name = "Arial"
        pt0.font.size = Pt(10)
        pt0.font.bold = True
        pt0.font.color.rgb = col_t
        pt0.space_after = Pt(3)

        pt1 = tf_tb.add_paragraph()
        pt1.text = title_t
        pt1.font.name = "Arial"
        pt1.font.size = Pt(14)
        pt1.font.bold = True
        pt1.font.color.rgb = TEXT_MAIN
        pt1.space_after = Pt(6)

        pt2 = tf_tb.add_paragraph()
        pt2.text = desc_t
        pt2.font.name = "Arial"
        pt2.font.size = Pt(10.5)
        pt2.font.color.rgb = TEXT_MUTED

    # =========================================================================
    # SLIDE 9: VIABILIDAD, COSTOS Y MITIGACIÓN DE RIESGOS
    # =========================================================================
    s9 = prs.slides.add_slide(blank_layout)
    add_bg(s9, CANVAS_LIGHT)
    add_header(s9, "08 / Viabilidad & Seguridad", "Mitigación de Riesgos: Seguridad institucional y comunitaria", dark=False, speaker="Eduardo (6:20 - 6:45)")

    risks = [
        ("Reseñas falsas y spam",
         "1 solo Visto Bueno por vecino verificado con GPS en la zona. Restricción única en Postgres: un usuario no puede calificar el mismo servicio dos veces ni votar por sí mismo.",
         "Transparencia comunitaria total"),
        ("Exposición de personas vulnerables",
         "La ubicación pública es aproximada (radio de ±200 metros). El teléfono y dirección exacta jamás son públicos a menos que el usuario decida enviarlo.",
         "Protección estricta de datos personales"),
        ("Falsos reportes de emergencia",
         "El modo SOS general solo puede ser activado por la Junta Vecinal. Los reportes ciudadanos pasan por estados auditables (Pendiente, En Atención, Atendido, No Verificado).",
         "Control y trazabilidad de auxilio"),
        ("Sostenibilidad financiera inicial",
         "Costo operativo de S/ 0 en etapa piloto utilizando el plan comunitario de Supabase y cartografía abierta OpenStreetMap sin licencias de pago.",
         "Viable desde el día 1 sin subsidios")
    ]

    for idx, (risk_title, risk_mit, risk_tag) in enumerate(risks):
        rb = s9.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(1.75 + idx * 1.28), Inches(11.7), Inches(1.15))
        rb.fill.solid()
        rb.fill.fore_color.rgb = WHITE
        rb.line.color.rgb = BORDER_LIGHT
        rb.line.width = Pt(1)

        tf_rb = rb.text_frame
        tf_rb.word_wrap = True
        tf_rb.margin_left = Inches(0.3)
        tf_rb.margin_top = Inches(0.18)
        tf_rb.margin_right = Inches(0.3)

        pr0 = tf_rb.paragraphs[0]
        pr0.text = f"RIESGO: {risk_title.upper()}"
        pr0.font.name = "Arial"
        pr0.font.size = Pt(11)
        pr0.font.bold = True
        pr0.font.color.rgb = RED_ALERT if idx == 2 else ORANGE_DEEP

        pr1 = tf_rb.add_paragraph()
        pr1.text = f"Mecanismo de Mitigación: {risk_mit}"
        pr1.font.name = "Arial"
        pr1.font.size = Pt(10.5)
        pr1.font.color.rgb = TEXT_MAIN

        # tag pill on right side
        rt_box = s9.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(9.2), Inches(1.9 + idx * 1.28), Inches(3.1), Inches(0.35))
        rt_box.fill.solid()
        rt_box.fill.fore_color.rgb = GREEN_SOFT
        rt_box.line.color.rgb = GREEN_VERIFIED
        rt_box.line.width = Pt(1)

        tf_rt = rt_box.text_frame
        tf_rt.vertical_anchor = MSO_ANCHOR.MIDDLE
        p_rt = tf_rt.paragraphs[0]
        p_rt.text = f"✓ {risk_tag}"
        p_rt.font.name = "Arial"
        p_rt.font.size = Pt(9.5)
        p_rt.font.bold = True
        p_rt.font.color.rgb = GREEN_VERIFIED
        p_rt.alignment = PP_ALIGN.CENTER

    # =========================================================================
    # SLIDE 10: ROADMAP & CONCLUSIONES
    # =========================================================================
    s10 = prs.slides.add_slide(blank_layout)
    add_bg(s10, CANVAS_LIGHT)
    add_header(s10, "09 / Visión de Futuro", "Roadmap de Despliegue y Conclusiones del Proyecto", dark=False, speaker="Eduardo (6:45 - 7:00)")

    # Left Roadmap 3 Steps
    rm_steps = [
        ("FASE 1 · MES 1", "Piloto Barrial Focalizado", "Despliegue en el sector Bellamar / Villa María (Nuevo Chimbote) validando 20 oficios base con la Junta Vecinal y comerciantes locales."),
        ("FASE 2 · MES 3", "Integración Municipal & COEN", "Panel web de telemetría para Defensa Civil y Serenazgo. Activación automática del modo emergencia ante alertas oficiales del COEN/INDECI."),
        ("FASE 3 · MES 6", "Malla Peer-to-Peer Bluetooth Mesh", "Transmisión de pedidos de rescate de teléfono a teléfono por proximidad Bluetooth sin necesidad de abrir la cámara ni escanear QR.")
    ]

    for idx, (phase, p_title, p_desc) in enumerate(rm_steps):
        rm_card = s10.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(1.75 + idx * 1.7), Inches(5.6), Inches(1.52))
        rm_card.fill.solid()
        rm_card.fill.fore_color.rgb = WHITE
        rm_card.line.color.rgb = BORDER_LIGHT
        rm_card.line.width = Pt(1)

        tf_rmc = rm_card.text_frame
        tf_rmc.word_wrap = True
        tf_rmc.margin_left = Inches(0.3)
        tf_rmc.margin_top = Inches(0.18)
        tf_rmc.margin_right = Inches(0.25)

        prm0 = tf_rmc.paragraphs[0]
        prm0.text = phase
        prm0.font.name = "Arial"
        prm0.font.size = Pt(10)
        prm0.font.bold = True
        prm0.font.color.rgb = ORANGE_DEEP

        prm1 = tf_rmc.add_paragraph()
        prm1.text = p_title
        prm1.font.name = "Arial"
        prm1.font.size = Pt(13)
        prm1.font.bold = True
        prm1.font.color.rgb = TEXT_MAIN
        prm1.space_after = Pt(3)

        prm2 = tf_rmc.add_paragraph()
        prm2.text = p_desc
        prm2.font.name = "Arial"
        prm2.font.size = Pt(9.5)
        prm2.font.color.rgb = TEXT_MUTED

    # Right 3 Impact Conclusions
    concl_card = s10.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(6.8), Inches(1.75), Inches(5.75), Inches(4.92))
    concl_card.fill.solid()
    concl_card.fill.fore_color.rgb = NAVY_CARD
    concl_card.line.color.rgb = BORDER_DARK
    concl_card.line.width = Pt(1)

    tf_cc = concl_card.text_frame
    tf_cc.word_wrap = True
    tf_cc.margin_left = tf_cc.margin_right = Inches(0.4)
    tf_cc.margin_top = Inches(0.4)

    pcc0 = tf_cc.paragraphs[0]
    pcc0.text = "TRES CONCLUSIONES PARA EL JURADO"
    pcc0.font.name = "Arial"
    pcc0.font.size = Pt(11)
    pcc0.font.bold = True
    pcc0.font.color.rgb = ORANGE_ACCENT
    pcc0.space_after = Pt(16)

    c_points = [
        ("1. Confianza Vecinal Medible y Real", "Reactivamos la economía de proximidad dando trabajo a los vecinos honrados y protegiendo al consumidor con el Visto Bueno auditado."),
        ("2. Resiliencia que no depende del Cable", "La Mula de Datos QR garantiza que en el peor escenario de desastre, la ayuda siga fluyendo de mano en mano cuando las antenas caigan."),
        ("3. Inclusión Genuina sin Barreras", "Con voz nativa, tamaño A++ y cero correos, aseguramos que ningún adulto mayor quede abandonado al margen de la tecnología.")
    ]

    for c_title, c_desc in c_points:
        pct = tf_cc.add_paragraph()
        pct.text = c_title
        pct.font.name = "Arial"
        pct.font.size = Pt(13)
        pct.font.bold = True
        pct.font.color.rgb = WHITE
        pct.space_after = Pt(2)

        pcd = tf_cc.add_paragraph()
        pcd.text = c_desc
        pcd.font.name = "Arial"
        pcd.font.size = Pt(10.5)
        pcd.font.color.rgb = RGBColor(203, 213, 225)
        pcd.space_after = Pt(14)

    # =========================================================================
    # SLIDE 11: ANEXO / BANCO DE RESPUESTAS AL JURADO (Q&A)
    # =========================================================================
    s11 = prs.slides.add_slide(blank_layout)
    add_bg(s11, NAVY_DEEP)
    add_header(s11, "Anexo de Preparación", "Banco de Preguntas Probables del Jurado (Q&A)", dark=True, speaker="Equipo AlphaCoders")

    qa_list = [
        ("¿Cómo evitan recomendaciones falsas o autovotos?",
         "Regla matemática en Postgres: 1 Visto Bueno por vecino registrado y constraint que prohíbe autovotarse. Además se valida la proximidad GPS del vecino."),
        ("¿Qué pasa si dos personas escanean y suben el mismo QR?",
         "Cada solicitud genera un identificador UUID único con marca de tiempo en el teléfono. El servidor de Supabase descarta duplicados sin generar conflicto."),
        ("¿El que lleva el QR (la mula) puede alterar la información?",
         "No. El payload del QR viaja con una lista blanca inmutable de campos y firma local. Quien lo transporta solo actúa como cartero, no como autor."),
        ("¿Por qué no cobrar comisiones por los servicios?",
         "Porque rompería la confianza inicial del barrio. El objetivo es costo cero; la app conecta y el acuerdo económico se realiza de forma directa entre vecinos."),
        ("¿Cómo escalan a otras ciudades del Perú?",
         "La arquitectura está parametrizada por zonas geográficas. Basta con desplegar una nueva zona en la tabla de sectores para abrir un nuevo distrito."),
        ("¿Qué pasa si la Junta Vecinal no activa la emergencia a tiempo?",
         "Roadmap Fase 2: Alertas automáticas disparadas por el umbral de reportes sísmicos del USGS o avisos oficiales de emergencia de INDECI / COEN.")
    ]

    for idx, (q_text, a_text) in enumerate(qa_list):
        x = Inches(0.8 + (idx % 2) * 5.95)
        y = Inches(1.85 + (idx // 2) * 1.7)

        qb = s11.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, x, y, Inches(5.65), Inches(1.52))
        qb.fill.solid()
        qb.fill.fore_color.rgb = NAVY_CARD
        qb.line.color.rgb = BORDER_DARK
        qb.line.width = Pt(1)

        tf_qb = qb.text_frame
        tf_qb.word_wrap = True
        tf_qb.margin_left = Inches(0.25)
        tf_qb.margin_top = Inches(0.18)
        tf_qb.margin_right = Inches(0.25)

        pq0 = tf_qb.paragraphs[0]
        pq0.text = f"P: {q_text}"
        pq0.font.name = "Arial"
        pq0.font.size = Pt(11)
        pq0.font.bold = True
        pq0.font.color.rgb = ORANGE_ACCENT
        pq0.space_after = Pt(4)

        pq1 = tf_qb.add_paragraph()
        pq1.text = f"R: {a_text}"
        pq1.font.name = "Arial"
        pq1.font.size = Pt(9.5)
        pq1.font.color.rgb = RGBColor(226, 232, 240)

    # Save presentation
    output_path = "Conecta_Vecino_Pitch.pptx"
    prs.save(output_path)
    print(f"Presentation generated successfully at: {output_path}")

if __name__ == "__main__":
    create_presentation()
