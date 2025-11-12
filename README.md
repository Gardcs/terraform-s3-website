# Terraform med AWS S3 og statiske websider

## Mål
Deploy en statisk nettside på AWS S3 ved hjelp av Terraform. Denne øvelsen dekker bruk av moduler fra Terraform Registry, håndtering av ressurser med AWS CLI, samt bruk av variabler og outputs i Terraform.

## Forberedelser

### Steg 0: Opprett GitHub Codespace fra din fork

1. **Fork dette repositoriet** til din egen GitHub-konto
2. **Åpne Codespace**: Klikk på "Code" → "Codespaces" → "Create codespace on main"
3. **Vent på at Codespace starter**: Dette kan ta et par minutter første gang
4. **Terminalvindu**: Du vil utføre de fleste kommandoer i terminalen som åpner seg nederst i Codespace
5. **AWS Credentials**. Kjør `aws configure` og legg inn AWS aksessnøkler. 


### Steg 1: Verifiser miljøet

Repositoriet er allerede klonet i ditt Codespace. Verifiser at du er i riktig mappe:

```bash
pwd
ls
```

Du skal se filene fra dette repositoriet, inkludert mappen `s3_demo_website`. 

### Steg 2: Opprett Terraform-konfigurasjon

Nå skal du bygge opp Terraform-konfigurasjonen fra bunnen av. Du vil lære om de ulike AWS S3-ressursene som trengs for å hoste en statisk nettside.

1. **Opprett `main.tf`** i rotmappen av prosjektet

2. **Opprett S3 bucket-ressursen** med et hardkodet bucket-navn (erstatt `<unikt-bucket-navn>` med ditt eget unike navn, f.eks. dine initialer eller studentnummer):
Det er ganske strenge regler for navn for buckets! https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html

```hcl
resource "aws_s3_bucket" "website" {
  bucket = "unikt-bucket-navn"
}
```

3. **Konfigurer S3 bucket for website hosting**:

```hcl
resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}
```

4. **Åpne bucketen for offentlig tilgang** (nødvendig for static websites):

```hcl
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
```

5. **Legg til en bucket policy som tillater offentlig lesing**:

```hcl
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website]
}
```

6. **Legg til en output for å få URL-en til nettsiden**:

```hcl
output "s3_website_url" {
  value = "http://${aws_s3_bucket.website.bucket}.s3-website.${aws_s3_bucket.website.region}.amazonaws.com"
  description = "URL for the S3 hosted website"
}
```

### Steg 3: Deploy infrastrukturen

Nå er du klar til å deploye infrastrukturen. Sørg for at du har erstattet `unikt-bucket-navn` i `main.tf` med ditt eget unike navn.

```bash
terraform init
terraform apply
```

**Merk**: Hvis du får en feilmelding om `AccessDenied` ved `PutBucketPolicy`, prøv kommandoen på nytt. Spør instruktør hvis du er nysgjerrig på hvorfor dette skjer.
**Viktig**: Pass på at du ikke får feilneldinger etter apply før du går videre.

### Steg 4: Last opp filer til S3


Bruk AWS CLI for å laste opp nettsidefilene til S3 bucketen:

```bash
aws s3 sync s3_demo_website s3://unikt-bucket-navn
```

### Steg 5: Inspiser bucketen i AWS Console

Gå til AWS Console, og tjenesten S3, og se på objekter og bucket-egenskaper for å forstå hvordan alt er satt opp.

### Steg 6: Åpne nettsiden

Hent URL-en til nettsiden:

```bash
terraform output s3_website_url
```

Åpne URL-en i nettleseren for å se din statiske nettside.

### Steg 7: Refaktorer til å bruke variabler

Nå som du har fått infrastrukturen til å fungere med hardkodet bucket-navn, skal vi gjøre konfigurasjonen mer fleksibel ved å introdusere variabler.

1. **Legg til en variabel for bucket-navnet** øverst i `main.tf`:

```hcl
variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}
```

2. **Erstatt det hardkodede bucket-navnet** i S3 bucket-ressursen:

```hcl
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name  # Endret fra hardkodet verdi
}
```

3. **Apply endringene** med variabelen:

```bash
terraform apply -var 'bucket_name=ditt_bucket_navn'
```

Terraform vil nå vise at det ikke er nødvendig med endringer, siden bucket-navnet er det samme.

**Fordelen med variabler**: Du kan nå enkelt endre bucket-navnet uten å redigere koden, og gjenbruke samme konfigurasjon for flere miljøer.

### Steg 8: Bruk default-verdier for variabler

I stedet for å måtte oppgi verdier på kommandolinjen hver gang, kan du sette default-verdier for variabler. Dette gjør det enklere å jobbe med Terraform i daglig bruk.

1. **Oppdater variabelen med en default-verdi**:

```hcl
variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "ditt-bucket-navn"  # Erstatt med ditt eget unike navn
}
```

2. **Apply uten å spesifisere variabel**:

```bash
terraform apply
```

Terraform vil nå bruke default-verdien uten at du må oppgi den på kommandolinjen.

**Best practice**: Bruk default-verdier for variabler som sjelden endres, men la kritiske verdier (som bucket-navn i produksjon) være uten default for å sikre at de blir eksplisitt satt.

### Bonusoppgave: Modifiser nettsiden

Prøv å endre HTML- og CSS-filene i `s3_demo_website`-mappen, og kjør sync-kommandoen på nytt for å se endringene:

```bash
aws s3 sync s3_demo_website s3://unikt-bucket-navn
```

## Oppsummering - Part 1

Du har nå deployet og håndtert en statisk nettside på AWS ved hjelp av Terraform og AWS CLI.

---

# Part 2: Avansert Terraform - Modules, Remote State og CI/CD

I denne delen skal vi utvide infrastrukturen med mer avanserte Terraform-konsepter. Du vil lære om:
- Remote state management for team-samarbeid
- Terraform modules for gjenbrukbar infrastruktur
- CloudFront CDN for global distribusjon
- Automatisering med GitHub Actions

**Estimert tid**: 1.5-2 timer

---

## Del 1: Remote State Management (15 min)

### Hvorfor Remote State?

Når flere personer jobber med samme infrastruktur, eller når vi skal automatisere med CI/CD, trenger vi en felles plass å lagre Terraform state. Lokal state fungerer ikke i team-miljøer.

### Steg 1: Opprett Backend-ressurser

Først må vi lage en S3 bucket og DynamoDB-tabell for state management. Disse må opprettes **før** vi konfigurerer backend.

1. **Opprett en ny fil** `backend-setup.tf` i rotmappen:

```hcl
# This file creates the resources needed for Terraform remote state
# Run this FIRST before configuring the backend

resource "aws_s3_bucket" "terraform_state" {
  bucket = "ditt-navn-terraform-state"  # Bytt til unikt navn

  tags = {
    Name        = "Terraform State"
    Environment = "Infrastructure"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Locks"
  }
}

output "backend_config" {
  value = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.terraform_state.id}"
      key            = "website/terraform.tfstate"
      region         = "${data.aws_region.current.name}"
      dynamodb_table = "${aws_dynamodb_table.terraform_locks.id}"
      encrypt        = true
    }
  EOT
  description = "Backend configuration to add to your terraform block"
}
```

2. **Deploy backend-ressursene**:

```bash
terraform apply
```

**Merk output** som viser backend-konfigurasjonen du skal bruke.

### Steg 2: Konfigurer Backend

1. **Opprett fil** `backend.tf` i rotmappen:

```hcl
terraform {
  backend "s3" {
    bucket         = "ditt-navn-terraform-state"  # Samme som i backend-setup.tf
    key            = "website/terraform.tfstate"
    region         = "eu-west-1"  # Din region
    dynamodb_table = "terraform-state-locks"
    encrypt        = true
  }
}
```

2. **Migrer state til remote backend**:

```bash
terraform init -migrate-state
```

Terraform vil spørre om du vil kopiere eksisterende state til det nye backend. Svar `yes`.

3. **Verifiser**:
   - Gå til S3 Console og se at state-filen er lastet opp
   - Din lokale `terraform.tfstate` skal nå være tom eller borte

**Gratulerer!** State er nå lagret sentralt. Hvis flere personer jobber på samme prosjekt, vil de alle dele samme state.

---

## Del 2: Terraform Modules - Gjenbrukbar Infrastruktur (45 min)

### Hva er Modules?

Modules er Terraforms måte å pakke og gjenbruke infrastruktur-kode på. I stedet for å copy-paste kode, lager vi en module som kan brukes flere steder med ulike konfigurasjoner.

**Analogi**: En module er som en funksjon i programmering - den tar inputs, gjør noe, og returnerer outputs.

### Del A: Guided - Lage Basic Module Structure (20 min)

#### Steg 1: Opprett Module-struktur

Lag følgende mappestruktur:

```
modules/
└── s3-website/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

```bash
mkdir -p modules/s3-website
touch modules/s3-website/main.tf
touch modules/s3-website/variables.tf
touch modules/s3-website/outputs.tf
```

#### Steg 2: Definer Module Variables

**Fyll inn** `modules/s3-website/variables.tf`:

```hcl
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "website_files_path" {
  description = "Path to website files to upload"
  type        = string
}
```

#### Steg 3: Flytt Ressurser til Module

**Flytt S3-ressursene** fra root `main.tf` til `modules/s3-website/main.tf`:

- Kopier alle S3-relaterte ressurser (`aws_s3_bucket`, `aws_s3_bucket_website_configuration`, etc.)
- Erstatt hardkodede verdier med `var.bucket_name`, `var.tags`, etc.
- Behold `locals` for MIME types

**Hint**: I modulen skal du bruke `var.bucket_name` i stedet for `local.website_bucket_name`.

#### Steg 4: Definer Module Outputs

**Fyll inn** `modules/s3-website/outputs.tf`:

```hcl
output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.website.id
}

output "website_url" {
  description = "URL of the S3 website"
  value       = "http://${aws_s3_bucket.website.bucket}.s3-website.${data.aws_region.current.name}.amazonaws.com"
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.website.arn
}

# Don't forget to add data source for region
data "aws_region" "current" {}
```

### Del B: Selvstendig - Bruk Modulen (25 min)

Nå skal **du selv** refaktorere root `main.tf` til å bruke modulen du nettopp laget.

#### Din oppgave:

1. **I root `main.tf`**: Erstatt alle S3-ressursene med et module-kall:

```hcl
module "s3_website" {
  source = "./modules/s3-website"

  bucket_name         = "ditt-bucket-navn"
  website_files_path  = "${path.root}/s3_demo_website/dist"

  tags = {
    Name        = "Crypto Juice Exchange"
    Environment = "Demo"
    ManagedBy   = "Terraform"
  }
}
```

2. **Oppdater outputs** i root `main.tf` til å bruke module outputs:

```hcl
output "s3_website_url" {
  value       = module.s3_website.website_url
  description = "URL for the S3 hosted website"
}

output "bucket_name" {
  value       = module.s3_website.bucket_name
  description = "Name of the S3 bucket"
}
```

3. **Test konfigurasjonen**:

```bash
terraform init  # Re-initialize for module
terraform plan
terraform apply
```

**Forventet resultat**: Terraform skal si at det ikke er noen endringer nødvendig (hvis du har flyttet alt riktig).

#### Utfordring (ekstra):

- Kan du legge til en `enable_versioning` variable i modulen som gjør versioning optional?
- Hint: Bruk `count` eller `for_each` basert på variabelen

```hcl
resource "aws_s3_bucket_versioning" "website" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.website.id
  # ...
}
```

---

## Del 3: CloudFront CDN - Minimal Setup (20 min)

### Hvorfor CloudFront?

S3 website hosting er bra, men har begrensninger:
- Ingen HTTPS support
- Ikke globalt distribuert (slow for brukere langt fra bucket region)
- Ingen custom domain uten ekstra setup

CloudFront løser alt dette, og krever overraskende lite kode!

### Legg til CloudFront Distribution

**Utvid** `modules/s3-website/main.tf` med CloudFront:

```hcl
# ============================================
# CloudFront Distribution for Global CDN
# ============================================

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "CDN for ${var.bucket_name}"

  # Origin - where CloudFront fetches content from
  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "S3-${var.bucket_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  # Custom error response for SPA routing
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  # Required: Restrictions (none in this case)
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Required: SSL certificate (use CloudFront default)
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}
```

### Legg til CloudFront Output

**Utvid** `modules/s3-website/outputs.tf`:

```hcl
output "cloudfront_url" {
  description = "CloudFront distribution URL (HTTPS enabled)"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "cloudfront_domain" {
  description = "CloudFront domain name"
  value       = aws_cloudfront_distribution.website.domain_name
}
```

### Oppdater Root Outputs

**I root `main.tf`**, legg til CloudFront output:

```hcl
output "cloudfront_url" {
  value       = module.s3_website.cloudfront_url
  description = "CloudFront URL with HTTPS"
}
```

### Deploy CloudFront

```bash
terraform apply
```

**Merk**: CloudFront deployment tar 5-15 minutter. Dette er normalt!

### Test CDN

```bash
terraform output cloudfront_url
```

Åpne URL-en i nettleseren. Legg merke til:
- HTTPS fungerer automatisk
- URL-en er global (CloudFront, ikke region-spesifikk)

**Imponerende enkelt, ikke sant?** Med ~40 linjer kode har du global CDN med HTTPS!

---

## Del 4: GitHub Actions CI/CD Pipeline (20-30 min)

### Mål

Automatiser Terraform deployment:
- **Pull Request**: Kjør `terraform plan` og vis endringer
- **Merge til main**: Kjør `terraform apply` automatisk

### Steg 1: Opprett Workflow Fil

**Lag** `.github/workflows/terraform.yml`:

```yaml
name: Terraform Infrastructure

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  AWS_REGION: eu-west-1
  TF_VERSION: 1.6.0

jobs:
  terraform:
    name: Terraform Plan & Apply
    runs-on: ubuntu-latest

    permissions:
      pull-requests: write
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Terraform Init
        run: terraform init

      - name: Terraform Format Check
        run: terraform fmt -check
        continue-on-error: true

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color
        continue-on-error: true

      - name: Comment Plan on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const output = `### Terraform Plan 📝

            \`\`\`
            ${{ steps.plan.outputs.stdout }}
            \`\`\`

            *Pushed by: @${{ github.actor }}*`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            })

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve
```

### Steg 2: Konfigurer GitHub Secrets

Du må gi GitHub Actions tilgang til AWS:

1. **Gå til ditt GitHub repository**
2. **Settings** → **Secrets and variables** → **Actions**
3. **Klikk "New repository secret"**
4. **Legg til to secrets**:
   - Name: `AWS_ACCESS_KEY_ID`, Value: `<din AWS access key>`
   - Name: `AWS_SECRET_ACCESS_KEY`, Value: `<din AWS secret key>`

**Sikkerhetstips**: Disse secrets bør være fra en dedicated IAM-bruker med minimal permissions (kun det Terraform trenger).

### Steg 3: Test Pipeline

1. **Lag en ny branch**:

```bash
git checkout -b test-pipeline
```

2. **Gjør en liten endring** (f.eks. i README eller legg til en tag):

```hcl
# I main.tf
module "s3_website" {
  # ...
  tags = {
    # ...
    PipelineTest = "true"  # Ny tag
  }
}
```

3. **Commit og push**:

```bash
git add .
git commit -m "Test GitHub Actions pipeline"
git push origin test-pipeline
```

4. **Opprett Pull Request** på GitHub

5. **Observer**:
   - GitHub Actions kjører `terraform plan`
   - En kommentar vises på PR med plan output
   - Du kan se hva som vil endres før merge

6. **Merge PR** til main:
   - GitHub Actions kjører `terraform apply` automatisk
   - Infrastrukturen oppdateres uten manuell intervensjon

**Gratulerer!** Du har nå full CI/CD for infrastrukturen din.

---

## Bonusoppgaver

### 1. Custom Domain (hvis du har et domene)

Legg til Route53 DNS:

```hcl
resource "aws_route53_record" "website" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}
```

### 2. Validation Rules på Module Variables

Legg til validation i `modules/s3-website/variables.tf`:

```hcl
variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must start and end with lowercase letter or number, and contain only lowercase letters, numbers, and hyphens."
  }
}
```

### 3. Multi-Environment Setup

Bruk samme module for dev og prod:

```hcl
module "dev_website" {
  source = "./modules/s3-website"
  bucket_name = "dev-${var.project_name}"
  tags = { Environment = "dev" }
}

module "prod_website" {
  source = "./modules/s3-website"
  bucket_name = "prod-${var.project_name}"
  tags = { Environment = "prod" }
}
```

---

## Oppsummering - Part 2

Du har nå lært:

✅ **Remote State Management**: State deling i team og CI/CD
✅ **Terraform Modules**: Gjenbrukbar, DRY infrastruktur-kode
✅ **CloudFront CDN**: Global distribusjon med HTTPS, minimal kode
✅ **GitHub Actions**: Automatisk testing og deployment av infrastruktur

**Neste steg**: Utforsk Terraform Registry for community modules, eller bygg dine egne komplekse modules!

---

## Ressurser

- [Terraform Modules Documentation](https://developer.hashicorp.com/terraform/language/modules)
- [AWS CloudFront Developer Guide](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/)
- [GitHub Actions Terraform Tutorial](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
