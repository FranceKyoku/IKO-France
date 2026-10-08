from dotenv import load_dotenv
load_dotenv()

import os
import json
import asyncio
import mysql.connector
from mysql.connector import errorcode
from spond import spond

# --- Récupération Sécurisée des Variables d'Environnement ---
SPOND_USERNAME = os.environ.get("SPOND_USERNAME")
SPOND_PASSWORD = os.environ.get("SPOND_PASSWORD")

DB_CONFIG = {
    'user': os.environ.get("DB_USER"),
    'password': os.environ.get("DB_PASSWORD"),
    'host': os.environ.get("DB_HOST"),
    'database': os.environ.get("DB_NAME"),
    'raise_on_warnings': False
}

def sync_to_mysql(group_id, group_name, group_description, field_map, members_data):
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        query = """
            INSERT INTO spond_members (spond_uid, group_id, group_name, group_description, first_name, last_name, email, membership_status, custom_fields)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s) AS new_row
            ON DUPLICATE KEY UPDATE 
                group_name = new_row.group_name,
                group_description = new_row.group_description,
                first_name = new_row.first_name,
                last_name = new_row.last_name,
                email = new_row.email,
                membership_status = new_row.membership_status,
                custom_fields = new_row.custom_fields;
        """
        
        records_updated = 0
        for m in members_data:
            profile = m.get('profile', {})
            uid = profile.get('id') or m.get('id')
            first_name = profile.get('firstName') or m.get('firstName', '')
            last_name = profile.get('lastName') or m.get('lastName', '')
            email = profile.get('email') or m.get('email', '')
            status = m.get('status', 'active') 
            
            # Extraction et résolution des champs personnalisés
            raw_fields = m.get('fields', {})
            custom_data = {}
            if isinstance(raw_fields, dict):
                for fid, fval in raw_fields.items():
                    label = field_map.get(fid, fid)
                    custom_data[label] = fval.get('value') if isinstance(fval, dict) else fval
            
            custom_fields_json = json.dumps(custom_data, ensure_ascii=False) if custom_data else None
            
            if uid:
                cursor.execute(query, (uid, group_id, group_name, group_description, first_name, last_name, email, status, custom_fields_json))
                records_updated += 1
        
        conn.commit()
        print(f" -> [{group_name}] Synchronisation réussie : {records_updated} membres traités.")
        
    except mysql.connector.Error as err:
        print(f" -> Erreur MySQL pour le groupe {group_name} : {err}")
    finally:
        if 'conn' in locals() and conn.is_connected():
            cursor.close()
            conn.close()

async def main():
    if not SPOND_USERNAME or not SPOND_PASSWORD:
        print("Erreur : Les identifiants Spond ne sont pas configurés dans l'environnement.")
        return

    print("Initialisation de la connexion avec l'API Spond...")
    s = spond.Spond(username=SPOND_USERNAME, password=SPOND_PASSWORD)
    
    try:
        groups = await s.get_groups()
        if not groups:
            print("Aucun groupe trouvé.")
            return
            
        for g in groups:
            group_id = g.get('id')
            group_details = await s.get_group(group_id)
            group_name = group_details.get('name') or g.get('name', 'Nom inconnu')
            group_description = group_details.get('welcomeMessage') or g.get('welcomeMessage') or ''
            
            # Mapping des définitions de champs personnalisés du club
            field_defs = group_details.get('fieldDefs') or []
            field_map = {f['id']: f.get('name', f['id']) for f in field_defs if isinstance(f, dict) and 'id' in f}
            
            print(f"Traitement du Club : '{group_name}' (ID: {group_id})")
            print(f" -> Id:{group_id}, Name:{group_name}, Details:{group_details}, Description:{group_description}.")

            members = group_details.get('members', [])
            print(f" -> Members:{members}.")
            if members:
                sync_to_mysql(group_id, group_name, group_description, field_map, members)
                
    except Exception as e:
        print(f"Échec critique de l'interrogation de l'API Spond : {e}")
    finally:
        await s.clientsession.close()

if __name__ == "__main__":
    asyncio.run(main())
