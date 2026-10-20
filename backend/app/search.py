import re
import math
import logging
from typing import List, Optional
from app.config import settings

logger = logging.getLogger(__name__)

class EmbeddingService:
    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY
        self.model = settings.GEMINI_MODEL
        self.embedding_model = settings.GEMINI_EMBEDDING_MODEL
        self.client = None
        
        if self.api_key:
            try:
                from google import genai
                self.client = genai.Client(api_key=self.api_key)
                logger.info(f"[Search] Initialized Google GenAI Client with priority model: {self.model}, embedding: {self.embedding_model}")
            except Exception as e:
                logger.warning(f"[Search] Could not initialize Google GenAI SDK: {e}. Fallback to token matching.")
        else:
            logger.info("[Search] GEMINI_API_KEY not configured. Using local intelligent token/fuzzy matching.")

    def get_embedding(self, text: str) -> Optional[List[float]]:
        if not text or not self.client:
            return None
            
        try:
            response = self.client.models.embed_content(
                model=self.embedding_model,
                contents=text
            )
            if response and hasattr(response, "embeddings") and response.embeddings:
                return response.embeddings[0].values
            elif response and hasattr(response, "embedding") and response.embedding:
                return response.embedding.values
        except Exception as e:
            logger.warning(f"[Search] Gemini embedding failed: {e}. Falling back to keyword search.")
            
        return None

    def expand_query(self, query: str) -> List[str]:
        """使用 Gemini 3.5 Flash Lite 進行快速同義詞與關聯物品擴充 (Free-tier 額度最高且最快)"""
        if not self.client or not query:
            return [query]
        try:
            resp = self.client.models.generate_content(
                model=self.model,
                contents=f"請為家庭庫存搜尋詞「{query}」列出 3 到 5 個最相關的物品名稱同義詞或關聯詞，以半形逗號分隔，只輸出逗號分隔字串，不要其他文字。"
            )
            if resp and resp.text:
                keywords = [k.strip() for k in resp.text.split(",") if k.strip()]
                return list(set([query] + keywords))
        except Exception as e:
            logger.debug(f"[Search] Query expansion failed: {e}")
        return [query]

    @staticmethod
    def cosine_similarity(v1: List[float], v2: List[float]) -> float:
        if not v1 or not v2 or len(v1) != len(v2):
            return 0.0
        dot = sum(a * b for a, b in zip(v1, v2))
        norm_a = math.sqrt(sum(a * a for a in v1))
        norm_b = math.sqrt(sum(b * b for b in v2))
        if norm_a == 0 or norm_b == 0:
            return 0.0
        return dot / (norm_a * norm_b)

    @staticmethod
    def calculate_text_score(query: str, target: str) -> float:
        q = query.strip().lower()
        t = target.strip().lower()
        if not q or not t:
            return 0.0
            
        if q == t:
            return 1.0
            
        if q in t:
            return min(0.95, 0.7 + (len(q) / len(t)) * 0.25)
            
        def get_bigrams(s):
            clean = re.sub(r'\s+', '', s)
            if len(clean) == 1:
                return {clean}
            return {clean[i:i+2] for i in range(len(clean)-1)}
            
        b_q = get_bigrams(q)
        b_t = get_bigrams(t)
        if not b_q or not b_t:
            return 0.0
            
        intersection = b_q.intersection(b_t)
        union = b_q.union(b_t)
        jaccard = len(intersection) / len(union) if union else 0.0
        
        chars_q = set(q)
        chars_t = set(t)
        char_overlap = len(chars_q.intersection(chars_t)) / len(chars_q) if chars_q else 0.0
        
        return max(jaccard, char_overlap * 0.6)

embedding_service = EmbeddingService()
