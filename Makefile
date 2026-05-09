up:
	docker compose up --build -d

down:
	docker compose down

logs:
	docker compose logs -f

restart:
	docker compose restart

build:
	docker build --target production -t docker-node-demo:latest .

shell:
	docker compose exec app1 sh

clean:
	docker compose down --rmi all --volumes
