# DevOps Assessment: Terraform + Database Reliability

AWS infrastructure design with Terraform (plan-only, no deployment) and a local PostgreSQL setup with seed data, indexing, backup and restore.

## Repository layout

~~~
docker-compose.yml          local PostgreSQL 16
db/migrations/              SQL migrations (tables, indexes)
db/seed/seed.sql            seed data (2000 bookings, 3000 events)
scripts/backup.sh           timestamped pg_dump
scripts/restore.sh          restore into a fresh database
scripts/tf-check.sh         offline Terraform fmt/validate/plan for dev and prod
infra/modules/              network, ecs, rds
infra/envs/dev, prod        per-environment config
.github/workflows/          Terraform PR workflow
~~~

## Prerequisites

Docker with Compose v2, Terraform >= 1.5.

## Part A: Local database

~~~bash
docker compose up -d
~~~

On first start Postgres runs the files in `db/` in order: `001` creates the tables, `002` adds the indexes, `003` loads seed data.

Verify:

~~~bash
docker compose exec db psql -U app -d hotel -c "SELECT COUNT(*) FROM hotel_bookings;"   # 2000
docker compose exec db psql -U app -d hotel -c "SELECT COUNT(*) FROM booking_events;"   # 3000
~~~

Seed data covers 5 cities, 3 organizations and 4 statuses (confirmed, cancelled, pending, completed), spread over the last 60 days. Every booking has a `booking_created` event, and confirmed/completed bookings also have a `booking_confirmed` event.

To start from scratch: `docker compose down -v && docker compose up -d`.

### Index choice

Query being optimized:

~~~sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
~~~

Index:

~~~sql
CREATE INDEX idx_bookings_city_created
  ON hotel_bookings (city, created_at)
  INCLUDE (org_id, status, amount);
~~~

- `city` is first because it is an equality filter.
- `created_at` is second because it is a range filter. An equality column followed by a range column lets Postgres read one contiguous slice of the index.
- `org_id`, `status` and `amount` are in `INCLUDE`: they are only needed for GROUP BY and SUM, not for searching. This makes it a covering index, so Postgres answers from the index alone without reading the table.

A second index on `booking_events (booking_id)` supports lookups of events per booking.

Verify:

~~~bash
docker compose exec db psql -U app -d hotel -c "VACUUM ANALYZE hotel_bookings;"
docker compose exec db psql -U app -d hotel -c "EXPLAIN ANALYZE SELECT org_id, status, COUNT(*), SUM(amount) FROM hotel_bookings WHERE city='delhi' AND created_at >= NOW() - INTERVAL '30 days' GROUP BY org_id, status;"
~~~

Observed plan: `Index Only Scan using idx_bookings_city_created`, `Heap Fetches: 0`, execution time about 2 ms.

### Backup and restore

~~~bash
./scripts/backup.sh     # creates backups/hotel_<YYYYMMDD_HHMMSS>.sql
./scripts/restore.sh    # restores the latest backup into a fresh database "hotel_restore"
~~~

`restore.sh` accepts an optional file path: `./scripts/restore.sh backups/hotel_xxx.sql`.

It drops and recreates `hotel_restore`, loads the dump, then prints row counts.

How to verify the restore worked: compare the original and restored databases.

~~~bash
docker compose exec db psql -U app -d hotel         -c "SELECT COUNT(*) FROM hotel_bookings;"
docker compose exec db psql -U app -d hotel_restore -c "SELECT COUNT(*) FROM hotel_bookings;"
docker compose exec db psql -U app -d hotel_restore -c "SELECT COUNT(*) FROM booking_events;"
docker compose exec db psql -U app -d hotel_restore -c "\di"    # indexes were restored too
~~~

Both databases must show the same counts (2000 bookings, 3000 events).

## Part B: Terraform

Architecture: `Internet -> ALB -> ECS Fargate (private subnets) -> RDS PostgreSQL (private subnets)`

Modules:

- `network`: VPC, 2 public and 2 private subnets, internet gateway, NAT gateway, route tables, and the ALB, ECS and RDS security groups.
- `rds`: private PostgreSQL 16 instance, encrypted, master password managed by AWS Secrets Manager.
- `ecs`: cluster, task definition (Nginx placeholder image), Fargate service, ALB, target group, listener, log group, execution role.

### How RDS stays private

- RDS sits in private subnets with `publicly_accessible = false`.
- The RDS security group allows port 5432 only from the ECS security group.
- The ECS security group allows port 80 only from the ALB security group.
- Only the ALB security group accepts traffic from the internet (port 80).

### Environments

| Setting | dev | prod |
|---|---|---|
| RDS instance | db.t3.micro | db.m5.large |
| RDS storage | 20 GB | 100 GB |
| Multi-AZ | false | true |
| Backup retention | 3 days | 14 days |
| Deletion protection | false | true |
| ECS CPU / memory | 256 / 512 | 1024 / 2048 |
| ECS tasks | 1 | 2 |
| State backend | s3 `caps-tfstate-dev` | s3 `caps-tfstate-prod` |

Each environment has its own `variables.tf`, `<env>.tfvars` and S3 backend configuration with DynamoDB locking.

### Validate (no AWS account needed)

~~~bash
./scripts/tf-check.sh
~~~

This runs `terraform fmt -check`, then for dev and prod: `init`, `validate` and `plan -refresh=false`. Expected result: both environments valid, `Plan: 28 to add, 0 to change, 0 to destroy.`

The environments use an S3 backend (see `infra/envs/<env>/main.tf`), which needs AWS access. To review without an AWS account, the script temporarily adds a `backend_override.tf` that switches to a local backend, and removes it afterwards. Dummy credentials are used, and the AWS provider skips credential and account checks, so nothing is contacted and nothing is deployed.

Manual equivalent for one environment:

~~~bash
cd infra/envs/dev
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
export AWS_ACCESS_KEY_ID=dummy AWS_SECRET_ACCESS_KEY=dummy AWS_DEFAULT_REGION=ap-south-1
terraform init
terraform validate
terraform plan -refresh=false -var-file=dev.tfvars
rm backend_override.tf
~~~

## GitHub Actions

`.github/workflows/terraform.yml` runs on pull requests that touch `infra/**`, for both dev and prod: `terraform fmt -check`, `init`, `validate`, `plan`. The plan is shown in the workflow run summary and uploaded as an artifact (`tfplan-dev`, `tfplan-prod`).
