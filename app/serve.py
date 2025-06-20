import subprocess
import sys

if __name__ == "__main__":
    subprocess.run(["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"])