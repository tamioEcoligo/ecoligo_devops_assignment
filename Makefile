install:
	pip install uv==0.8.22
	uv pip install -r requirements.txt

unittest:
	pytest -n auto --cov-config=tox.ini --cov=. --cov-report term-missing tests

run:
	uvicorn app.main:app --reload
