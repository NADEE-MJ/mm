"""Entrypoint for running the FastAPI app with `python main.py`."""

from app.main import app

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
