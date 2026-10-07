"""
face_service.py
-----------------
ส่วนจัดการ AI สำหรับจดจำใบหน้า
- สกัด embedding จากรูปภาพ
- เปรียบเทียบ embedding เพื่อหาว่าเป็นใคร (recognition)

ใช้ DeepFace ซึ่งครอบโมเดลดังๆ ไว้ให้ใช้ง่าย (Facenet512, ArcFace, VGG-Face ฯลฯ)
เลือกใช้ Facenet512 เป็นค่าเริ่มต้นเพราะสมดุลระหว่างความแม่นยำกับความเร็ว
"""

import json
import base64
import numpy as np
import cv2
from deepface import DeepFace

MODEL_NAME = "Facenet512"
DETECTOR_BACKEND = "opencv"  # เปลี่ยนเป็น "retinaface" ได้ถ้าต้องการแม่นยำขึ้น (แต่ช้าลง)
SIMILARITY_THRESHOLD = 0.65  # ค่าความคล้าย (cosine similarity) ขั้นต่ำที่ถือว่า "ใช่คนเดียวกัน" ต้อง tune ตามข้อมูลจริง


def decode_base64_image(base64_string: str) -> np.ndarray:
    """แปลงรูปจาก base64 (ที่ frontend ส่งมาจากกล้อง) เป็น numpy array (OpenCV format)"""
    if "," in base64_string:
        base64_string = base64_string.split(",")[1]
    img_bytes = base64.b64decode(base64_string)
    img_arr = np.frombuffer(img_bytes, dtype=np.uint8)
    img = cv2.imdecode(img_arr, cv2.IMREAD_COLOR)
    return img


def extract_embedding(image: np.ndarray) -> list:
    """
    สกัด face embedding จากภาพ 1 ภาพ
    คืนค่า: list ของตัวเลข (vector) ที่แทนลักษณะใบหน้า
    ถ้าตรวจไม่พบใบหน้า จะ raise Exception (ให้ endpoint จับ error ไปแจ้ง user)
    """
    result = DeepFace.represent(
        img_path=image,
        model_name=MODEL_NAME,
        detector_backend=DETECTOR_BACKEND,
        enforce_detection=True,
    )
    # DeepFace.represent คืนเป็น list (เผื่อเจอหลายหน้าในภาพ) เราเอาหน้าแรก
    embedding = result[0]["embedding"]
    return embedding


def cosine_similarity(vec_a: list, vec_b: list) -> float:
    """คำนวณความคล้ายระหว่าง embedding สองอัน (0 = ไม่เหมือนกันเลย, 1 = เหมือนกันทุกประการ)"""
    a = np.array(vec_a)
    b = np.array(vec_b)
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b)))


def find_best_match(query_embedding: list, all_user_embeddings: dict) -> tuple:
    """
    เทียบ embedding ที่ scan เข้ามา กับ embedding ของทุกคนในฐานข้อมูล
    all_user_embeddings: dict รูปแบบ { user_id: [embedding1, embedding2, ...] }
    คืนค่า: (best_user_id, best_score) หรือ (None, 0) ถ้าไม่พบใครที่ผ่าน threshold
    """
    best_user_id = None
    best_score = 0.0

    for user_id, embeddings in all_user_embeddings.items():
        for emb_str in embeddings:
            emb = json.loads(emb_str)
            score = cosine_similarity(query_embedding, emb)
            if score > best_score:
                best_score = score
                best_user_id = user_id

    if best_score < SIMILARITY_THRESHOLD:
        return None, best_score

    return best_user_id, best_score
