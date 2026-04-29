import sqlite3
import os
import math
from dotenv import load_dotenv
from pinecone import Pinecone
from sentence_transformers import SentenceTransformer
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

PINECONE_API_KEY = os.getenv("PINECONE_API_KEY")
if not PINECONE_API_KEY:
    # Also check if Pinecone_api_key might be the case since previously we saw that
    PINECONE_API_KEY = os.getenv("Pinecone_api_key")
if not PINECONE_API_KEY:
    raise ValueError("Missing PINECONE_API_KEY in .env file")

db_path = "new_schemes.db"
index_name = "scheme-data"
PINECONE_HOST = os.getenv("PINECONE_HOST")
batch_size = 64  # Batch size for encoding and uploading

def main():
    logger.info("Initializing Pinecone client...")
    pc = Pinecone(api_key=PINECONE_API_KEY)
    index = pc.Index(index_name, host=PINECONE_HOST)

    logger.info("Connecting to SQLite database...")
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM schemes")
    rows = cursor.fetchall()
    conn.close()

    if not rows:
        logger.warning("No schemes found in the database. Exiting.")
        return

    logger.info(f"Loaded {len(rows)} schemes from database.")

    logger.info("Initializing SentenceTransformer model ('BAAI/bge-base-en-v1.5'). This may take a moment to download if not cached...")
    model = SentenceTransformer('BAAI/bge-base-en-v1.5')

    logger.info("Processing and uploading in batches...")

    total_batches = math.ceil(len(rows) / batch_size)
    for i in range(0, len(rows), batch_size):
        batch_rows = rows[i:i + batch_size]
        
        texts_to_embed = []
        metadata_list = []
        ids_list = []

        for row in batch_rows:
            scheme_id = str(row['scheme_id'])
            
            scheme_name = str(row['scheme_name'] or '')
            brief_desc = str(row['brief_description'] or '')
            state = str(row['state'] or '')
            category = str(row['category'] or '')
            tags = str(row['tags'] or '')
            eligibility = str(row['eligibility_criteria'] or '')
            
            text_to_embed = f"Scheme Name: {scheme_name}. State: {state}. Category: {category}. Tags: {tags}. Description: {brief_desc}. Eligibility: {eligibility}"
            texts_to_embed.append(text_to_embed)
            
            metadata = {
                "scheme_id": scheme_id,
                "scheme_name": scheme_name,
                "state": state,
                "category": category,
                "tags": tags,
                "brief_description": brief_desc,
                "eligibility_criteria": eligibility
            }
            # Remove empty values to save payload space and prevent metadata errors if any
            metadata = {k: v for k, v in metadata.items() if v}

            metadata_list.append(metadata)
            ids_list.append(f"scheme_{scheme_id}")

        # Compute embeddings
        embeddings = model.encode(texts_to_embed, normalize_embeddings=True, show_progress_bar=False).tolist()
        
        vectors = []
        for j in range(len(batch_rows)):
            vectors.append({
                "id": ids_list[j],
                "values": embeddings[j],
                "metadata": metadata_list[j]
            })
            
        # Upsert
        try:
            index.upsert(vectors=vectors)
            logger.info(f"Uploaded batch {i//batch_size + 1}/{total_batches} ({len(batch_rows)} items)")
        except Exception as e:
            logger.error(f"Error uploading batch {i//batch_size + 1}: {str(e)}")
            raise e

    logger.info("Finished uploading all schemes to Pinecone.")

if __name__ == "__main__":
    main()
