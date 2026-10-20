import logging
import re
import hashlib
import urllib.request
import json

logger = logging.getLogger(__name__)

class EmbeddingService:
    def __init__(self, dim: int = 384):
        self.dim = dim
        self.api_url = "https://api-inference.huggingface.co/pipeline/feature-extraction/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
        logger.info("Embedding service initialized with Hugging Face API & Hashing Vectorizer Fallback.")

    def _tokenize(self, text: str) -> list[str]:
        text = text.lower()
        words = re.findall(r'[a-z0-9]+', text)
        chinese = re.findall(r'[\u4e00-\u9fff]', text)
        
        ngrams = []
        clean_text = re.sub(r'\s+', '', text)
        for i in range(len(clean_text) - 1):
            ngrams.append(clean_text[i:i+2])
            
        return words + chinese + ngrams

    def _get_local_embedding(self, text: str) -> list[float]:
        tokens = self._tokenize(text)
        vector = [0.0] * self.dim
        if not tokens:
            return vector
            
        for token in tokens:
            h = int(hashlib.md5(token.encode('utf-8')).hexdigest(), 16)
            idx = h % self.dim
            sign = 1 if ((h >> 4) & 1) == 1 else -1
            vector[idx] += sign
            
        norm = sum(x * x for x in vector) ** 0.5
        if norm > 0:
            vector = [x / norm for x in vector]
        return vector

    def get_embedding(self, text: str) -> list[float]:
        if not text:
            return [0.0] * self.dim
            
        try:
            # Attempt to fetch high-quality sentence embeddings from HuggingFace
            req_data = json.dumps({"inputs": text}).encode('utf-8')
            req = urllib.request.Request(
                self.api_url, 
                data=req_data,
                headers={"Content-Type": "application/json"}
            )
            # 3 second timeout for quick fallback
            with urllib.request.urlopen(req, timeout=3.0) as response:
                result = json.loads(response.read().decode('utf-8'))
                # Result should be a list of floats (embedding size 384)
                if isinstance(result, list) and len(result) == self.dim:
                    return result
                elif isinstance(result, list) and isinstance(result[0], list):
                    # In case API returns list of lists (batch representation)
                    return result[0]
                else:
                    logger.warning("HuggingFace API returned invalid shape, using local fallback.")
        except Exception as e:
            logger.info(f"HuggingFace API unavailable or timed out ({e}). Using local signed hashing vectorizer.")
            
        # Fallback to local signed hashing vectorizer
        return self._get_local_embedding(text)

embedding_service = EmbeddingService()
