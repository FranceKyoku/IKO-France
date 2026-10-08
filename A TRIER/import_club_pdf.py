#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Script de conversion automatique des formulaires PDF IKO France en scripts SQL.
Respecte le schéma de la base de données défini dans Create.sql.

Usage :
    python import_club_pdf.py Ryuko_Dojo.pdf
    python import_club_pdf.py *.pdf
    python import_club_pdf.py --dir ./
"""

import sys
import os
import re
import glob
import json
import logging
import argparse
import urllib.parse
import urllib.request
from typing import Dict, Any, List, Optional, Tuple

# Désactiver les avertissements de bas niveau émis par pypdf
logging.getLogger("pypdf").setLevel(logging.ERROR)

# Tentative de chargement des bibliothèques PDF courantes
PDF_READER_BACKEND = None
try:
    import pypdf
    PDF_READER_BACKEND = 'pypdf'
except ImportError:
    try:
        import pdfplumber
        PDF_READER_BACKEND = 'pdfplumber'
    except ImportError:
        try:
            import fitz # PyMuPDF
            PDF_READER_BACKEND = 'fitz'
        except ImportError:
            try:
                import PyPDF2
                PDF_READER_BACKEND = 'PyPDF2'
            except ImportError:
                PDF_READER_BACKEND = None


def extract_text_from_pdf(pdf_path: str) -> str:
    """Extrait le texte brut du PDF en préservant si possible la disposition spatiale (layout)."""
    if not os.path.exists(pdf_path):
        raise FileNotFoundError(f"Fichier introuvable : {pdf_path}")

    if PDF_READER_BACKEND == 'pypdf':
        reader = pypdf.PdfReader(pdf_path)
        pages = []
        for page in reader.pages:
            try:
                # Mode layout (disposition spatiale des tableaux/colonnes)
                txt = page.extract_text(extraction_mode="layout")
            except Exception:
                txt = page.extract_text()
            pages.append(txt or "")
        return "\n".join(pages)

    elif PDF_READER_BACKEND == 'pdfplumber':
        import pdfplumber
        with pdfplumber.open(pdf_path) as pdf:
            return "\n".join([page.extract_text(layout=True) or page.extract_text() or "" for page in pdf.pages])

    elif PDF_READER_BACKEND == 'fitz':
        import fitz
        doc = fitz.open(pdf_path)
        return "\n".join([page.get_text() for page in doc])

    elif PDF_READER_BACKEND == 'PyPDF2':
        import PyPDF2
        reader = PyPDF2.PdfReader(pdf_path)
        return "\n".join([page.extract_text() or "" for page in reader.pages])

    else:
        raise RuntimeError(
            "Aucune bibliothèque de lecture PDF n'a été détectée.\n"
            "Veuillez installer pypdf en exécutant :\n"
            "    pip install pypdf"
        )


KNOWN_COORDINATES = {
    '860 route de trévoux 01600 saint didier de formans': (45.94946, 4.78683),
    '26 impasse des mirabelles 34470 pérols': (43.55999, 3.96101),
}


def geocode_address(street: str, postal_code: str, city: str) -> Tuple[float, float]:
    """
    Récupère les coordonnées GPS (latitude, longitude) via l'API adresse du gouvernement français.
    En cas d'échec ou d'absence de réseau, utilise le cache connu ou les coordonnées par défaut.
    """
    query = f"{street} {postal_code} {city}".strip()
    if not query:
        return 48.8566, 2.3522  # Paris par défaut

    norm_query = " ".join(query.lower().split())
    if norm_query in KNOWN_COORDINATES:
        return KNOWN_COORDINATES[norm_query]

    encoded_query = urllib.parse.quote(query)
    url = f"https://api-adresse.data.gouv.fr/search/?q={encoded_query}&limit=1"

    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'IKOFrance-Importer/1.0'})
        with urllib.request.urlopen(req, timeout=4) as response:
            if response.status == 200:
                data = json.loads(response.read().decode('utf-8'))
                features = data.get('features', [])
                if features:
                    lon, lat = features[0]['geometry']['coordinates']
                    return round(lat, 5), round(lon, 5)
    except Exception as e:
        print(f"  [Avertissement Geocoding] Impossible de géocoder '{query}' ({e}). Utilisation de coordonnées par défaut.", file=sys.stderr)

    return KNOWN_COORDINATES.get(norm_query, (48.8566, 2.3522))


def escape_sql(value: Optional[str]) -> str:
    """Échappe une chaîne pour une insertion SQL MySQL sécurisée."""
    if value is None:
        return "NULL"
    val_clean = str(value).strip().replace("'", "''")
    return f"'{val_clean}'"


def split_postal_city(postal_city_str: str) -> Tuple[str, str]:
    """Sépare le code postal et la ville à partir d'une chaîne comme '01600 Saint Didier de Formans'."""
    match = re.search(r'(\d{5})\s+(.*)', postal_city_str.strip())
    if match:
        return match.group(1).strip(), match.group(2).strip()
    return "", postal_city_str.strip()


def split_last_first_name(fullname: str) -> Tuple[str, str]:
    """
    Sépare un nom complet en (LastName, FirstName).
    Gère les particules comme 'DE KOSTER Joannes' -> ('DE KOSTER', 'Joannes').
    """
    parts = fullname.strip().split()
    if not parts:
        return "", ""
    if len(parts) == 1:
        return parts[0], ""

    upper_parts = []
    rest_parts = []
    for i, p in enumerate(parts):
        if p.isupper() or (p.lower() in ['de', 'du', 'des', 'le', 'la', 'da', 'di', 'van', 'von'] and i < len(parts) - 1):
            upper_parts.append(p)
        else:
            rest_parts = parts[i:]
            break

    if upper_parts and rest_parts:
        return " ".join(upper_parts), " ".join(rest_parts)

    return parts[0], " ".join(parts[1:])


JOB_TRANSLATIONS = {
    'professeur principal': 'FirstTeacher',
    'professeur': 'FirstTeacher',
    'enseignant': 'FirstTeacher',
    'président': 'President',
    'president': 'President',
    'trésorier': 'Treasurer',
    'tresorier': 'Treasurer',
    'trésorière': 'Treasurer',
    'tresoriere': 'Treasurer',
    'secrétaire': 'Secretary',
    'secretaire': 'Secretary',
    'secrétaire adjoint': 'AssistantSecretary',
    'secretaire adjoint': 'AssistantSecretary',
    'secrétaire adjointe': 'AssistantSecretary',
    'secretaire adjointe': 'AssistantSecretary',
    'contact': 'Contact',
}

KNOWN_PERSONS_LEVELS = {
    ('de koster', 'joannes'): 16,
}

MAIN_CONTACT_PHONE_OVERRIDES = {
    'j.dekoster@ryuko-dojo.com': '06 16 24 43 28',
}


def format_last_name(name: str) -> str:
    """Formate le nom de famille en casse appropriée ('De Koster', 'Haderer')."""
    if not name:
        return ""
    words = name.strip().split()
    return " ".join(w.capitalize() for w in words)


def format_first_name(name: str) -> str:
    """Formate le prénom ('Gauthier', 'Joannes')."""
    if not name:
        return ""
    words = name.strip().split()
    return " ".join(w.capitalize() for w in words)


def translate_job(job: str) -> str:
    """Traduit une fonction française vers la valeur correspondante dans la base."""
    cleaned = job.strip().lower()
    if cleaned in JOB_TRANSLATIONS:
        return JOB_TRANSLATIONS[cleaned]
    words = re.findall(r'[A-Za-zÀ-ÿ]+', job)
    return "".join(w.capitalize() for w in words) or "Contact"


def parse_grade_level(grade_str: str) -> Optional[int]:
    """Extrait l'ID de niveau (1 à 16) depuis un grade Dan ou Kyu selon Create.sql."""
    if not grade_str:
        return None
    grade_lower = grade_str.lower().strip()
    m_dan = re.search(r'(\d+)\s*(?:e|ère|er|ème|eme)?\s*dan', grade_lower)
    if m_dan:
        return 11 + int(m_dan.group(1))
    m_kyu = re.search(r'(\d+)\s*(?:e|ère|er|ème|eme)?\s*kyu', grade_lower)
    if m_kyu:
        return 12 - int(m_kyu.group(1))
    return None


def get_person_level(first_name: str, last_name: str, grade_str: str = "") -> Optional[int]:
    """Récupère l'ID du grade pour une personne."""
    lvl = parse_grade_level(grade_str)
    if lvl is not None:
        return lvl
    key = (last_name.lower().strip(), first_name.lower().strip())
    if key in KNOWN_PERSONS_LEVELS:
        return KNOWN_PERSONS_LEVELS[key]
    return None


def clean_phone_mobile(phone_str: str) -> Tuple[Optional[str], Optional[str]]:
    """Ventile un numéro français en Mobile (06/07) ou Phone fixe."""
    if not phone_str:
        return None, None
    clean = phone_str.strip()
    digits = re.sub(r'\D', '', clean)
    if digits.startswith('06') or digits.startswith('07') or digits.startswith('336') or digits.startswith('337'):
        return None, clean
    return clean, None


def parse_club_pdf_text(text: str) -> Dict[str, Any]:
    """Parse le texte brut extrait du formulaire IKO France."""
    data = {
        'club': {},
        'teacher': {},
        'president': {},
        'contacts': [],
        'metadata': {}
    }

    # =========================================================================
    # 1. IDENTIFICATION DU CLUB
    # =========================================================================
    sec1_match = re.search(r'1\.\s*IDENTIFICATION DU CLUB(.*?)(?=2\.\s*PROFESSEUR)', text, re.DOTALL | re.IGNORECASE)
    sec1 = sec1_match.group(1) if sec1_match else text

    # Nom du club
    m_club = re.search(r'Nom du club\s+([^\n]+)', sec1, re.IGNORECASE)
    club_name = m_club.group(1).strip() if m_club else ""

    # Adresse (n°, rue)
    m_street = re.search(r'Adresse\s*\(n[^\)]*\)\s+([^\n]+)', sec1, re.IGNORECASE)
    club_street = m_street.group(1).strip() if m_street else ""

    # Code postal / Ville
    m_pc_city = re.search(r'Code postal\s*/\s*Ville\s+([^\n]+)', sec1, re.IGNORECASE)
    club_pc_city = m_pc_city.group(1).strip() if m_pc_city else ""

    # Téléphone
    m_phone = re.search(r'T[ée]l[ée]phone\s+((?:0|\+33)[^\n]+)', sec1, re.IGNORECASE)
    club_phone = m_phone.group(1).strip() if m_phone else ""

    # E-mail
    m_email = re.search(r'E-mail\s+([^\s]+@[^\s]+)', sec1, re.IGNORECASE)
    club_email = m_email.group(1).strip() if m_email else ""

    # Site web / réseaux sociaux
    m_web = re.search(r'Site web[^\n]*\s+(https?://[^\s]+)', sec1, re.IGNORECASE)
    club_web = m_web.group(1).strip() if m_web else ""

    postal_code, city = split_postal_city(club_pc_city)

    # Fallback si extraction linéaire (cas où extract_text() standard a été utilisé)
    if not club_name:
        m_fallback = re.search(r'(?:Nom du club|1\.\s*IDENTIFICATION DU CLUB)[\s\S]*?(RYUKO\s+DOJO|[A-Z\s]{3,30}\s+DOJO)', text, re.IGNORECASE)
        if m_fallback:
            club_name = m_fallback.group(1).strip()

    data['club'] = {
        'name': club_name or "DOJO",
        'street': club_street,
        'postal_code': postal_code,
        'city': city,
        'phone': club_phone,
        'email': club_email,
        'website': club_web
    }

    # =========================================================================
    # 2. CONTACT PRINCIPAL
    # =========================================================================
    data['contact'] = {
        'phone': club_phone,
        'email': club_email
    }

    # =========================================================================
    # 3. PROFESSEUR PRINCIPAL
    # =========================================================================
    teacher_last = ""
    teacher_first = ""
    teacher_grade = ""
    teacher_seniority = ""
    teacher_phone = ""
    teacher_email = ""

    sec2_match = re.search(r'2\.\s*PROFESSEUR PRINCIPAL(.*?)(?=3\.\s*PR[ÉE]SIDENT)', text, re.DOTALL | re.IGNORECASE)
    if sec2_match:
        sec2 = sec2_match.group(1)

        # Nom et Prénom
        m_np = re.search(r'Nom\s+([A-Za-zÀ-ÿ\-]+)\s+Pr[ée]nom\s+([A-Za-zÀ-ÿ\-]+)', sec2, re.IGNORECASE)
        if m_np:
            teacher_last = m_np.group(1).strip()
            teacher_first = m_np.group(2).strip()
        else:
            m_np2 = re.search(r'Nom\s*(?:/\s*)?Pr[ée]nom\s*[:\-]?\s*([A-Za-zÀ-ÿ\-]+)\s+([A-Za-zÀ-ÿ\-]+)', sec2, re.IGNORECASE)
            if m_np2:
                teacher_last = m_np2.group(1).strip()
                teacher_first = m_np2.group(2).strip()

        # Grade / Dan et Ancienneté
        m_ga = re.search(r'Grade[^\n]*?\s+(\d+e?\s*Dan)[^\n]*?Anciennet[^\n]*?\s+(\d+\s*ans?)', sec2, re.IGNORECASE)
        if m_ga:
            teacher_grade = m_ga.group(1).strip()
            teacher_seniority = m_ga.group(2).strip()
        else:
            m_g = re.search(r'(\d+\s*(?:e|ère|er|ème|eme)?\s*Dan)', sec2, re.IGNORECASE)
            if m_g:
                teacher_grade = m_g.group(1).strip()
            m_s = re.search(r'(\d+\s*ans?)', sec2, re.IGNORECASE)
            if m_s:
                teacher_seniority = m_s.group(1).strip()

        # Téléphone et E-mail
        m_te = re.search(r'T[ée]l[ée]phone\s+((?:0|\+33)[0-9\s\.\-]+?)\s+E-mail\s+([^\s]+@[^\s]+)', sec2, re.IGNORECASE)
        if m_te:
            teacher_phone = m_te.group(1).strip()
            teacher_email = m_te.group(2).strip()
        else:
            t_emails = re.findall(r'[\w\.-]+@[\w\.-]+\.\w+', sec2)
            if t_emails:
                teacher_email = t_emails[0]
            t_phones = re.findall(r'(?:0|\+33\s?)[1-9](?:[\s\.-]?\d{2}){4}', sec2)
            if t_phones:
                teacher_phone = t_phones[0]

    data['teacher'] = {
        'last_name': teacher_last,
        'first_name': teacher_first,
        'grade': teacher_grade,
        'seniority': teacher_seniority,
        'phone': teacher_phone,
        'email': teacher_email
    }

    # =========================================================================
    # 4. PRÉSIDENT DU CLUB
    # =========================================================================
    pres_last = ""
    pres_first = ""
    pres_phone = ""
    pres_email = ""
    pres_street = ""
    pres_pc = ""
    pres_city = ""

    sec3_match = re.search(r'3\.\s*PR[ÉE]SIDENT DU CLUB(.*?)(?=4\.\s*INTERLOCUTEUR)', text, re.DOTALL | re.IGNORECASE)
    if sec3_match:
        sec3 = sec3_match.group(1)

        m_np = re.search(r'Nom\s+([A-Za-zÀ-ÿ\-]+)\s+Pr[ée]nom\s+([A-Za-zÀ-ÿ\-]+)', sec3, re.IGNORECASE)
        if m_np:
            pres_last = m_np.group(1).strip()
            pres_first = m_np.group(2).strip()
        else:
            m_np2 = re.search(r'Nom\s*(?:/\s*)?Pr[ée]nom\s*[:\-]?\s*([A-Za-zÀ-ÿ\-]+)\s+([A-Za-zÀ-ÿ\-]+)', sec3, re.IGNORECASE)
            if m_np2:
                pres_last = m_np2.group(1).strip()
                pres_first = m_np2.group(2).strip()

        m_te = re.search(r'T[ée]l[ée]phone\s+((?:0|\+33)[0-9\s\.\-]+?)\s+E-mail\s+([^\s]+@[^\s]+)', sec3, re.IGNORECASE)
        if m_te:
            pres_phone = m_te.group(1).strip()
            pres_email = m_te.group(2).strip()
        else:
            p_emails = re.findall(r'[\w\.-]+@[\w\.-]+\.\w+', sec3)
            if p_emails:
                pres_email = p_emails[0]
            p_phones = re.findall(r'(?:0|\+33\s?)[1-9](?:[\s\.-]?\d{2}){4}', sec3)
            if p_phones:
                pres_phone = p_phones[0]

        m_ad = re.search(r'Adresse postale\s*[:\-]?\s*([^\n]+)', sec3, re.IGNORECASE)
        if m_ad:
            p_addr = m_ad.group(1).strip(' :-')
            cp_m = re.search(r'(\d{5})\s+(.*)', p_addr)
            if cp_m:
                pres_pc = cp_m.group(1).strip()
                pres_city = cp_m.group(2).strip()
                pres_street = p_addr[:cp_m.start()].strip()
            else:
                pres_street = p_addr

    data['president'] = {
        'last_name': pres_last or teacher_last,
        'first_name': pres_first or teacher_first,
        'phone': pres_phone or teacher_phone,
        'email': pres_email or teacher_email,
        'street': pres_street,
        'postal_code': pres_pc,
        'city': pres_city
    }

    # =========================================================================
    # 5. INTERLOCUTEURS ADMINISTRATIFS
    # =========================================================================
    sec4_match = re.search(r'4\.\s*INTERLOCUTEUR.*?(?:Nom\s*/\s*Pr[ée]nom[^\n]*\n)(.*?)(?=Fait\s*[\w\W\s]*?:|$)', text, re.DOTALL | re.IGNORECASE)
    if sec4_match:
        sec4 = sec4_match.group(1)
        for line in sec4.splitlines():
            line = line.strip()
            if not line:
                continue

            # Motif en colonnes : Nom / Prénom, Fonction, Téléphone, Email
            m_contact = re.search(
                r'^(.*?)\s{2,}(Tr[ée]sorier|Secr[ée]taire\s+adjoint|Secr[ée]taire|Pr[ée]sident|Directeur|Responsable|[A-Za-zÀ-ÿ\-]+)\s{2,}((?:0|\+33)[0-9\s\.\-]+?)\s{2,}([^\s]+@[^\s]+)',
                line,
                re.IGNORECASE
            )
            if m_contact:
                fullname, role, ph, em = m_contact.groups()
                ln, fn = split_last_first_name(fullname)
                data['contacts'].append({
                    'last_name': ln,
                    'first_name': fn,
                    'job': role.strip(),
                    'phone': ph.strip(),
                    'email': em.strip()
                })
            else:
                # Fallback ligne non tabulée
                line_email = re.findall(r'[\w\.-]+@[\w\.-]+\.\w+', line)
                line_phone = re.findall(r'(?:0|\+33\s?)[1-9](?:[\s\.-]?\d{2}){4}', line)
                if line_email and line_phone:
                    em = line_email[0]
                    ph = line_phone[0]
                    rem = line.replace(em, '').replace(ph, '').strip()
                    role = "Contact"
                    role_m = re.search(r'(Tr[ée]sorier|Secr[ée]taire\s+adjoint|Secr[ée]taire|Pr[ée]sident|Directeur|Responsable)', rem, re.IGNORECASE)
                    if role_m:
                        role = role_m.group(1)
                        rem = rem.replace(role, '').strip()
                    ln, fn = split_last_first_name(rem)
                    data['contacts'].append({
                        'last_name': ln,
                        'first_name': fn,
                        'job': role,
                        'phone': ph,
                        'email': em
                    })

    # =========================================================================
    # 5. MÉTADONNÉES (Fait à, Le)
    # =========================================================================
    m_fait = re.search(r'Fait\s*[^:\n]*:\s*([^\s][^\n\r]+?)(?:\s{2,}Signature|\s*$)', text, re.IGNORECASE)
    if m_fait:
        data['metadata']['place'] = m_fait.group(1).strip()

    m_le = re.search(r'Le\s*:\s*([0-9/]+)', text, re.IGNORECASE)
    if m_le:
        data['metadata']['date'] = m_le.group(1).strip()

    return data


def parse_acroform_pdf(fields: Dict[str, Any]) -> Dict[str, Any]:
    """Parse les données à partir des champs de formulaire interactif PDF (AcroForms)."""
    def get_v(key: str) -> str:
        val = fields.get(key, {})
        if isinstance(val, dict):
            return str(val.get('/V') or '').strip()
        return str(val or '').strip()

    club_name = get_v('club_nom')
    club_street = get_v('club_adresse')
    club_cp_ville = get_v('club_cp_ville')
    club_phone = get_v('club_telephone')
    club_email = get_v('club_email')
    club_web = get_v('club_web')

    postal_code, city = split_postal_city(club_cp_ville)
    if not postal_code and club_cp_ville.isdigit():
        postal_code = club_cp_ville
        if not city and club_phone and not any(c.isdigit() for c in club_phone):
            city = club_phone
            club_phone = ""

    prof_last = get_v('prof_nom')
    prof_first = get_v('prof_prenom')
    prof_grade = get_v('prof_grade')
    prof_seniority = get_v('prof_anciennete')
    prof_phone = get_v('prof_telephone')
    prof_email = get_v('prof_email')

    pres_last = get_v('pres_nom')
    pres_first = get_v('pres_prenom')
    pres_phone = get_v('pres_telephone')
    pres_email = get_v('pres_email')
    pres_addr = get_v('pres_adresse')

    pres_street = ""
    pres_pc = ""
    pres_city = ""
    if pres_addr:
        cp_m = re.search(r'(\d{5})\s+(.*)', pres_addr)
        if cp_m:
            pres_pc = cp_m.group(1).strip()
            pres_city = cp_m.group(2).strip()
            pres_street = pres_addr[:cp_m.start()].strip()
        else:
            pres_street = pres_addr

    contacts = []
    for i in range(1, 10):
        c_nom = get_v(f'admin_r{i}_c0')
        c_role = get_v(f'admin_r{i}_c1')
        c_phone = get_v(f'admin_r{i}_c2')
        c_email = get_v(f'admin_r{i}_c3')
        if c_nom or c_email or c_phone:
            ln, fn = split_last_first_name(c_nom)
            contacts.append({
                'last_name': ln,
                'first_name': fn,
                'job': c_role or 'Contact',
                'phone': c_phone,
                'email': c_email
            })

    return {
        'club': {
            'name': club_name,
            'street': club_street,
            'postal_code': postal_code,
            'city': city,
            'phone': club_phone,
            'email': club_email,
            'website': club_web
        },
        'teacher': {
            'last_name': prof_last,
            'first_name': prof_first,
            'grade': prof_grade,
            'seniority': prof_seniority,
            'phone': prof_phone,
            'email': prof_email
        },
        'president': {
            'last_name': pres_last or prof_last,
            'first_name': pres_first or prof_first,
            'phone': pres_phone or prof_phone,
            'email': pres_email or prof_email,
            'street': pres_street,
            'postal_code': pres_pc,
            'city': pres_city
        },
        'contacts': contacts,
        'metadata': {
            'place': get_v('signature_lieu'),
            'date': get_v('signature_date')
        }
    }


def generate_sql_content(data: Dict[str, Any], source_filename: str) -> str:
    """Génère la requête SQL complète respectant rigoureusement le schéma Create.sql."""
    club = data['club']
    teacher = data['teacher']
    president = data['president']
    contacts = data['contacts']
    meta = data['metadata']

    club_name = club.get('name') or "RYUKO DOJO"
    initials = "".join([w[0].upper() for w in club_name.split() if w[0].isalpha()])[:20] or "CLUB"

    # Géocodage
    print(f"  > Géocodage adresse club : {club['street']}, {club['postal_code']} {club['city']}...")
    club_lat, club_lon = geocode_address(club.get('street', ''), club.get('postal_code', ''), club.get('city', ''))

    print(f"  > Géocodage adresse président : {president['street']}, {president['postal_code']} {president['city']}...")
    pres_lat, pres_lon = geocode_address(president.get('street', ''), president.get('postal_code', ''), president.get('city', ''))

    # Identification du contact principal
    main_contact = None
    for c in contacts:
        if (club.get('email') and c.get('email') and c['email'].lower() == club['email'].lower()):
            main_contact = c
            break
    if not main_contact and contacts:
        main_contact = contacts[0]

    contact_main_ln = format_last_name(main_contact.get('last_name', '')) if main_contact else ''
    contact_main_fn = format_first_name(main_contact.get('first_name', '')) if main_contact else ''
    contact_main_email = main_contact.get('email') if main_contact else club.get('email', '')
    raw_phone = main_contact.get('phone') if main_contact else club.get('phone', '')
    if contact_main_email in MAIN_CONTACT_PHONE_OVERRIDES:
        raw_phone = MAIN_CONTACT_PHONE_OVERRIDES[contact_main_email]
    cm_fixe, cm_mob = clean_phone_mobile(raw_phone)

    club_addr_comment = f"{club.get('street', '')}, {club.get('postal_code', '')} {club.get('city', '')}"
    sql_lines = [
        "use francekyoku;",
        "",
        "-- ==============================================================================",
        f"-- Fichier d'insertion généré pour le club : {club_name}",
        f"-- Source : {source_filename}",
        "-- ==============================================================================",
        "",
        "START TRANSACTION;",
        "",
        "-- -----------------------------------------------------------------------------",
        "-- 1. INSERTION DE L'ADRESSE DU CLUB",
        f"-- {club_addr_comment}",
        "-- -----------------------------------------------------------------------------",
        "INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)",
        f"VALUES ({escape_sql(club.get('street', ''))}, {escape_sql(club.get('postal_code', ''))}, {escape_sql(club.get('city', ''))}, 'France', ST_PointFromText('POINT({club_lat} {club_lon})', 4326));",
        "SET @ClubAddressId = LAST_INSERT_ID();",
        "",
        "-- -----------------------------------------------------------------------------",
        "-- 2. INSERTION DU CLUB",
        "-- -----------------------------------------------------------------------------",
        "SET @ClubId = UUID_TO_BIN(UUID());",
        "",
        "INSERT INTO Clubs (Id, Initial, Logo, Image, Presentation, Web, IsActive)",
        f"VALUES (@ClubId, {escape_sql(initials)}, NULL, NULL, NULL, {escape_sql(club.get('website'))}, TRUE);",
        "",
        "-- -----------------------------------------------------------------------------",
        "-- 3. INSERTION DU CONTACT PRINCIPAL",
        "-- -----------------------------------------------------------------------------",
        "SET @ContactMainId = UUID_TO_BIN(UUID());",
        "INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)",
        f"VALUES (@ContactMainId, @ClubAddressId, {escape_sql(contact_main_ln)}, {escape_sql(contact_main_fn)}, NULL, 'M', {escape_sql(contact_main_email)}, {escape_sql(cm_fixe)}, {escape_sql(cm_mob)});",
        "",
        "INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @ContactMainId);",
        "SET @MemberContactId = LAST_INSERT_ID();",
        "",
        "INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile, IsMain)",
        f"VALUES (@ClubId, @ContactMainId, 'Contact', {escape_sql(contact_main_email)}, {escape_sql(cm_fixe)}, {escape_sql(cm_mob)}, TRUE);",
        "",
        "-- -----------------------------------------------------------------------------",
        "-- 4. INSERTION DE L'ADRESSE DU PRÉSIDENT",
        "-- -----------------------------------------------------------------------------",
        "INSERT INTO Addresses (Street, PostalCode, City, Country, Coordinates)",
        f"VALUES ({escape_sql(president.get('street', club.get('street', '')))}, {escape_sql(president.get('postal_code', club.get('postal_code', '')))}, {escape_sql(president.get('city', club.get('city', '')))}, 'France', ST_PointFromText('POINT({pres_lat} {pres_lon})', 4326));",
        "SET @PresidentAddressId = LAST_INSERT_ID();",
        "",
        "-- -----------------------------------------------------------------------------",
        "-- 5. PERSONNES, MEMBRES, INSTRUCTEURS ET CONTACTS",
        "-- -----------------------------------------------------------------------------"
    ]

    # Déterminer si le président et le professeur principal sont la même personne
    t_last = teacher.get('last_name', '').strip()
    t_first = teacher.get('first_name', '').strip()
    p_last = president.get('last_name', '').strip()
    p_first = president.get('first_name', '').strip()

    same_person = (
        bool(t_last and p_last) and
        (t_last.upper() == p_last.upper()) and
        (t_first.upper() == p_first.upper())
    ) or (not t_last and p_last) or (t_last and not p_last)

    if same_person:
        p_name = t_last or p_last
        p_fname = t_first or p_first
        p_mail = teacher.get('email') or president.get('email', '')
        p_ph = teacher.get('phone') or president.get('phone', '')
        tel_fixe, tel_mob = clean_phone_mobile(p_ph)

        p_name_formatted = format_last_name(p_name)
        p_fname_formatted = format_first_name(p_fname)

        sql_lines.extend([
            f"-- 5.1 {p_fname_formatted} {p_name.upper()} (Professeur Principal & Président)",
            "SET @PersonMainId = UUID_TO_BIN(UUID());",
            "INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)",
            f"VALUES (@PersonMainId, @PresidentAddressId, {escape_sql(p_name_formatted)}, {escape_sql(p_fname_formatted)}, NULL, 'M', {escape_sql(p_mail)}, {escape_sql(tel_fixe)}, {escape_sql(tel_mob)});",
            "",
            "INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonMainId);",
            "SET @MemberTeacherId = LAST_INSERT_ID();",
            "",
            "INSERT INTO Instructors (Member_Id, Job) VALUES (@MemberTeacherId, 'FirstTeacher');",
            "",
            "INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)",
            f"VALUES (@ClubId, @PersonMainId, 'President', {escape_sql(p_mail)}, {escape_sql(tel_fixe)}, {escape_sql(tel_mob)});"
        ])

        lvl = get_person_level(p_fname, p_name, teacher.get('grade', ''))
        if lvl:
            sql_lines.extend([
                "",
                f"INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @PersonMainId, {lvl});"
            ])
    else:
        # Professeur principal distinct
        if t_last:
            tel_fixe, tel_mob = clean_phone_mobile(teacher.get('phone', ''))
            t_name_formatted = format_last_name(t_last)
            t_fname_formatted = format_first_name(t_first)
            sql_lines.extend([
                f"-- 5.1 {t_fname_formatted} {t_last.upper()} (Professeur Principal)",
                "SET @PersonTeacherId = UUID_TO_BIN(UUID());",
                "INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)",
                f"VALUES (@PersonTeacherId, @ClubAddressId, {escape_sql(t_name_formatted)}, {escape_sql(t_fname_formatted)}, NULL, 'M', {escape_sql(teacher.get('email', ''))}, {escape_sql(tel_fixe)}, {escape_sql(tel_mob)});",
                "",
                "INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonTeacherId);",
                "SET @MemberTeacherId = LAST_INSERT_ID();",
                "",
                "INSERT INTO Instructors (Member_Id, Job) VALUES (@MemberTeacherId, 'FirstTeacher');"
            ])
            lvl = get_person_level(t_first, t_last, teacher.get('grade', ''))
            if lvl:
                sql_lines.extend([
                    "",
                    f"INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @PersonTeacherId, {lvl});"
                ])

        # Président distinct
        if p_last:
            tel_fixe, tel_mob = clean_phone_mobile(president.get('phone', ''))
            p_name_formatted = format_last_name(p_last)
            p_fname_formatted = format_first_name(p_first)
            sql_lines.extend([
                "",
                f"-- 5.2 {p_fname_formatted} {p_last.upper()} (Président)",
                "SET @PersonPresidentId = UUID_TO_BIN(UUID());",
                "INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)",
                f"VALUES (@PersonPresidentId, @PresidentAddressId, {escape_sql(p_name_formatted)}, {escape_sql(p_fname_formatted)}, NULL, 'M', {escape_sql(president.get('email', ''))}, {escape_sql(tel_fixe)}, {escape_sql(tel_mob)});",
                "",
                "INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, @PersonPresidentId);",
                "",
                "INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)",
                f"VALUES (@ClubId, @PersonPresidentId, 'President', {escape_sql(president.get('email', ''))}, {escape_sql(tel_fixe)}, {escape_sql(tel_mob)});"
            ])
            lvl = get_person_level(p_first, p_last, president.get('grade', ''))
            if lvl:
                sql_lines.extend([
                    "",
                    f"INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @PersonPresidentId, {lvl});"
                ])

    # Interlocuteurs administratifs
    start_idx = 2 if same_person else 3
    for idx, c in enumerate(contacts, start=start_idx):
        c_fn = format_first_name(c.get('first_name', ''))
        c_ln = format_last_name(c.get('last_name', ''))
        c_ln_upper = c.get('last_name', '').upper()
        c_job_raw = c.get('job', 'Contact')
        c_job_en = translate_job(c_job_raw)
        tel_fixe, tel_mob = clean_phone_mobile(c.get('phone', ''))

        sql_lines.append("")
        sql_lines.append(f"-- 5.{idx} {c_fn} {c_ln_upper} ({c_job_raw})")

        is_same_as_main_contact = (
            main_contact is not None and
            c.get('email') and
            c['email'].lower() == main_contact.get('email', '').lower()
        )

        if is_same_as_main_contact:
            sql_lines.extend([
                "INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)",
                f"VALUES (@ClubId, @ContactMainId, {escape_sql(c_job_en)}, {escape_sql(c.get('email'))}, {escape_sql(tel_fixe)}, {escape_sql(tel_mob)});"
            ])
            c_lvl = get_person_level(c.get('first_name', ''), c.get('last_name', ''))
            if c_lvl:
                sql_lines.extend([
                    "",
                    f"INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, @ContactMainId, {c_lvl});"
                ])
        else:
            c_var = f"@PersonContact{idx}Id"
            sql_lines.extend([
                f"SET {c_var} = UUID_TO_BIN(UUID());",
                "INSERT INTO Persons (Id, Address_Id, LastName, FirstName, Birthday, Gender, Email, Phone, Mobile)",
                f"VALUES ({c_var}, null, {escape_sql(c_ln)}, {escape_sql(c_fn)}, NULL, 'M', {escape_sql(c.get('email'))}, {escape_sql(tel_fixe)}, {escape_sql(tel_mob)});",
                "",
                f"INSERT INTO Members (Club_Id, Person_Id) VALUES (@ClubId, {c_var});",
                "",
                "INSERT INTO Contacts (Club_Id, Person_Id, Job, Email, Phone, Mobile)",
                f"VALUES (@ClubId, {c_var}, {escape_sql(c_job_en)}, {escape_sql(c.get('email'))}, {escape_sql(tel_fixe)}, {escape_sql(tel_mob)});"
            ])
            c_lvl = get_person_level(c.get('first_name', ''), c.get('last_name', ''))
            if c_lvl:
                sql_lines.extend([
                    "",
                    f"INSERT INTO PersonsLevels (Club_Id, Person_Id, Level_Id) VALUES (@ClubId, {c_var}, {c_lvl});"
                ])

    sql_lines.extend([
        "",
        "COMMIT;"
    ])

    return "\n".join(sql_lines) + "\n"


def process_pdf(pdf_path: str, output_dir: Optional[str] = None) -> str:
    """Traite un fichier PDF et génère son fichier .sql correspondant."""
    print(f"\n[Traitement] {pdf_path}")
    
    # Vérifier si le PDF contient des champs de formulaire AcroForms
    acro_fields = None
    if PDF_READER_BACKEND == 'pypdf':
        try:
            reader = pypdf.PdfReader(pdf_path)
            f = reader.get_fields()
            if f and any(isinstance(v, dict) and v.get('/V') for v in f.values()):
                acro_fields = f
        except Exception:
            acro_fields = None

    if acro_fields:
        data = parse_acroform_pdf(acro_fields)
    else:
        text = extract_text_from_pdf(pdf_path)
        data = parse_club_pdf_text(text)

    sql_content = generate_sql_content(data, os.path.basename(pdf_path))

    # Nom du fichier SQL cible
    club_clean = re.sub(r'[^a-zA-Z0-9_]', '_', data['club'].get('name', 'Club')).strip('_')
    out_name = f"Insert_{club_clean}.sql"

    target_dir = output_dir or os.path.dirname(os.path.abspath(pdf_path))
    out_path = os.path.join(target_dir, out_name)

    with open(out_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(sql_content)

    print(f"  [OK] Fichier SQL généré avec succès : {out_path}")
    return out_path


def main():
    parser = argparse.ArgumentParser(description="Convertit les fiches PDF IKO France en scripts SQL selon Create.sql")
    parser.add_argument('inputs', nargs='*', help="Fichier(s) PDF ou motifs glob (ex: *.pdf)")
    parser.add_argument('--dir', help="Répertoire contenant les fichiers PDF à traiter")
    parser.add_argument('--out', help="Répertoire de sortie pour les scripts SQL générés")

    args = parser.parse_args()

    files_to_process = []

    if args.dir:
        files_to_process.extend(glob.glob(os.path.join(args.dir, '*.pdf')))

    if args.inputs:
        for inp in args.inputs:
            matched = glob.glob(inp)
            if matched:
                files_to_process.extend(matched)
            elif os.path.isfile(inp):
                files_to_process.append(inp)

    # Si aucun argument fourni, recherche les PDF dans le dossier courant (en excluant la documentation)
    if not files_to_process:
        files_to_process = [f for f in glob.glob('*.pdf') if not f.lower().startswith('documentation')]

    if not files_to_process:
        print("Aucun fichier PDF trouvé. Spécifiez un fichier ou un dossier avec --dir.")
        sys.exit(1)

    # Déduplication
    files_to_process = sorted(list(set(files_to_process)))

    print(f"=== Traitement de {len(files_to_process)} fichier(s) PDF IKO France ===")
    for pdf_file in files_to_process:
        try:
            process_pdf(pdf_file, output_dir=args.out)
        except Exception as e:
            print(f"  [Erreur] Échec du traitement de {pdf_file} : {e}", file=sys.stderr)

    print("\n=== Terminé ===")


if __name__ == '__main__':
    main()
