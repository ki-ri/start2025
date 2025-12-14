.PHONY: up down

up:
	docker-compose up -d --build

down:
	docker-compose down

down-with-volumes:
	docker-compose down -v

DIR = ./migrations
DATABASE_URL = postgres://postgres:password@localhost:55432/demo?sslmode=disable

# example: make migrate-create-create_table_foo
migrate-create-%:
	migrate create -ext sql -dir $(DIR) ${@:migrate-create-%=%}

migrate-reset:
	migrate -path $(DIR) -database $(DATABASE_URL) down 1

migrate-up:
	migrate -path $(DIR) -database $(DATABASE_URL) up

migrate-down:
	migrate -path $(DIR) -database $(DATABASE_URL) down

migrate-version:
	migrate -path $(DIR) -database $(DATABASE_URL) version

migrate-force-%:
	migrate -path $(DIR) -database $(DATABASE_URL) force ${@:migrate-force-%=%}