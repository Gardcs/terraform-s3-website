# Terraform med AWS S3 og statiske websider

## Oppgaven

I denne øvelsen skal du hoste en React-applikasjon som viser kryptovaluta-informasjon på en morsom og interaktiv måte. Applikasjonen er allerede bygget og klar til å deployes - din jobb er å lære hvordan man bruker Terraform for å sette opp infrastrukturen for å hoste den på AWS.

Du vil bruke **Infrastructure as Code (IaC)** for å automatisere hele prosessen med å sette opp:
- En S3 bucket for å hoste nettsiden
- CloudFront CDN for global distribusjon og HTTPS
- DNS-konfigurasjon for custom domenenavn
- CI/CD pipeline for automatisk deployment

## Du vil lære

Gjennom denne øvelsen vil du mestre:

- **Terraform grunnleggende**: Ressurser, variabler, outputs og state management
- **AWS S3 Website Hosting**: Konfigurasjon av S3 buckets for statiske nettsider
- **CloudFront CDN**: Global distribusjon med HTTPS og caching
- **Terraform-moduler**: Bygge gjenbrukbar infrastruktur-kode
- **Remote State**: Håndtere Terraform state i team-miljøer
- **CI/CD med GitHub Actions**: Automatisere infrastruktur-deployment
- **Infrastructure as Code**: Best practices for å versjonere og administrere infrastruktur

## Forberedelser

### Steg 0: Opprett GitHub Codespace fra din fork

1. **Fork dette repositoriet** til din egen GitHub-konto
2. **Åpne Codespace**: Klikk på "Code" → "Codespaces" → "Create codespace on main"
3. **Vent på at Codespace starter**: Dette kan ta et par minutter første gang
4. **Terminalvindu**: Du vil utføre de fleste kommandoer i terminalen som åpner seg nederst i Codespace
5. **AWS Credentials**. Kjør `aws configure` og legg inn AWS aksessnøkler.

**Ekspert tips**: Trykk `.` (punktum) når du er i et GitHub repository for å åpne det direkte i en nettleser-basert VS Code editor. Dette er raskere enn å starte en full Codespace og perfekt for raske editeringer! 


### Steg 1: Verifiser miljøet

Repositoriet er allerede klonet i ditt Codespace. Verifiser at du er i riktig mappe:

```bash
pwd
ls
```

Du skal se filene fra dette repositoriet, inkludert mappen `s3_demo_website`. 

### Steg 2: Opprett Terraform-konfigurasjon

Nå skal du bygge opp Terraform-konfigurasjonen fra bunnen av. Du vil lære om de ulike AWS S3-ressursene som trengs for å hoste en statisk nettside.

1. **Opprett `providers.tf`** i rotmappen av prosjektet:

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# Alias provider for us-east-1
# Nødvendig for CloudFront ACM-sertifikater senere i oppgaven
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}
```

**Forklaring:**
- `required_version` sikrer at Terraform-versjonen er minst 1.0
- `required_providers` spesifiserer AWS provider versjon (~> 5.0 betyr versjon 5.x)
- Default provider bruker `eu-west-1`
- Aliased provider for `us-east-1` vil brukes senere for ACM-sertifikater (se [Appendix A](#appendix-a-provider-configuration-i-moduler))

2. **Opprett `main.tf`** i rotmappen av prosjektet

3. **Opprett S3 bucket-ressursen** med et hardkodet bucket-navn (erstatt `<unikt-bucket-navn>` med ditt eget unike navn, f.eks. dine initialer eller studentnummer):

**Viktig om bucket-navn:**
- S3 bucket-navn må være **globalt unike** på tvers av alle AWS-kontoer i hele verden
- Hvis noen andre allerede bruker navnet "my-website", kan du ikke bruke det samme navnet
- Bruk derfor noe unikt som dine initialer, studentnummer, eller en kombinasjon: `glennbech-pgr301-website`
- Det er også strenge regler for formatet: https://docs.aws.amazon.com/AmazonS3/latest/userguide/bucketnamingrules.html

```hcl
resource "aws_s3_bucket" "website" {
  bucket = "unikt-bucket-navn"  # Bytt til noe globalt unikt
}
```

4. **Konfigurer S3 bucket for website hosting**:

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

5. **Åpne bucketen for offentlig tilgang** (nødvendig for static websites):

```hcl
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}
```

6. **Legg til en bucket policy som tillater offentlig lesing**:

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

7. **Legg til en output for å få URL-en til nettsiden**:

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

### Steg 4: Bygg React-applikasjonen

Før vi kan laste opp nettsiden til S3, må vi bygge React-applikasjonen. Dette kompilerer TypeScript-koden og optimaliserer alle assets for produksjon.

1. **Naviger til applikasjonsmappen**:

```bash
cd s3_demo_website
```

2. **Installer dependencies** (hvis ikke allerede gjort):

```bash
npm install
```

3. **Bygg applikasjonen**:

```bash
npm run build
```

Dette vil opprette en `dist`-mappe med den ferdige produksjonsklare nettsiden.

4. **Gå tilbake til rotmappen**:

```bash
cd ..
```

### Steg 5: Last opp filer til S3

Nå kan vi laste opp den bygde nettsiden til S3 bucketen ved hjelp av AWS CLI:

```bash
aws s3 sync s3_demo_website/dist s3://unikt-bucket-navn
```

Legg merke til at vi synkroniserer `dist`-mappen, ikke hele `s3_demo_website`-mappen. `dist`-mappen inneholder kun de optimaliserte filene som trengs for produksjon.

### Steg 6: Inspiser bucketen i AWS Console

Gå til AWS Console, og tjenesten S3, og se på objekter og bucket-egenskaper for å forstå hvordan alt er satt opp.

### Steg 7: Åpne nettsiden

Hent URL-en til nettsiden:

```bash
terraform output s3_website_url
```

Åpne URL-en i nettleseren for å se din statiske nettside.

### Steg 8: Refaktorer til å bruke variabler

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

**Pro tips**: Hvis du er helt sikker på hva du gjør - og liker å leve litt risikabelt - kan du bruke `terraform apply --auto-approve` for å hoppe over bekreftelsen. Men vær oppmerksom på at dette kan føre til utilsiktede endringer hvis du ikke har sjekket planen først.

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

# Part 2: Avansert Terraform - Moduler, Remote State og CI/CD

I denne delen skal vi utvide infrastrukturen med mer avanserte Terraform-konsepter. Du vil lære om:
- Remote state management for team-samarbeid
- Terraform-moduler for gjenbrukbar infrastruktur
- CloudFront CDN for global distribusjon
- Automatisering med GitHub Actions

---

## Del 1: Remote State Management

### Hvorfor Remote State?

Når flere personer jobber med samme infrastruktur, eller når vi skal automatisere med CI/CD, trenger vi en felles plass å lagre Terraform state. Lokal state fungerer ikke i team-miljøer.

### Steg 1: Opprett Backend-ressurser

Først må vi lage en S3 bucket og DynamoDB-tabell for state management. Disse må opprettes **før** vi konfigurerer backend.

1. **Opprett en ny fil** `backend-setup.tf` i rotmappen:

```hcl
# This file creates the resources needed for Terraform remote state
# Run this FIRST before configuring the backend

data "aws_region" "current" {}

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
  name         = "ditt-navn-terraform-state-locks"  # Bytt til unikt navn
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

1. **Opprett fil** `backend.tf` i rotmappen.

Du kan kopiere backend-konfigurasjonen fra output av forrige `terraform apply`, eller skrive den manuelt:

```hcl
terraform {
  backend "s3" {
    bucket         = "ditt-navn-terraform-state"  # Samme som i backend-setup.tf
    key            = "website/terraform.tfstate"
    region         = "eu-west-1"  # Din region
    dynamodb_table = "ditt-navn-terraform-state-locks"  # Samme som i backend-setup.tf
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

**Gratulerer!** State er nå lagret sentralt. Hvis flere personer jobber på samme prosjekt, vil de alle dele samme state. I tillegg er dere nå beskyttet mot at flere gjør `terraform apply` samtidig - DynamoDB-tabellen sørger for state locking slik at kun én person kan gjøre endringer om gangen.

### Test State Locking

Du kan teste state locking ved å åpne to terminaler og prøve å kjøre `terraform apply` i begge samtidig:

1. **Terminal 1**: Kjør `terraform apply` og bekreft med `yes`
2. **Terminal 2**: Kjør raskt `terraform apply` mens Terminal 1 fortsatt jobber

**Tips**: Du må være litt rask, siden `terraform apply` går ganske fort når det ikke er mange endringer!

Du vil se at Terminal 2 får en feilmelding om at state er låst, med informasjon om hvem som holder låsen. Dette forhindrer at to personer gjør motstridende endringer samtidig.

---

## Del 2: Terraform-moduler - Gjenbrukbar Infrastruktur

### Hva er moduler?

Moduler er Terraforms måte å pakke og gjenbruke infrastruktur-kode på. I stedet for å copy-paste kode, lager vi en modul som kan brukes flere steder med ulike konfigurasjoner.

**Analogi**: En modul er som en funksjon i programmering - den tar inputs (variabler), utfører operasjoner (ressurser), og returnerer outputs.

### Modulstruktur

En typisk Terraform-modul består av følgende filer:

```
modules/s3-website/
├── main.tf        # Hovedressurser (S3, CloudFront, etc.)
├── variables.tf   # Input-variabler som modulen tar imot
├── outputs.tf     # Output-verdier som modulen returnerer
└── versions.tf    # Provider requirements (valgfri)
```

**Fordeler med moduler:**
- **Gjenbrukbarhet**: Samme modul kan brukes i flere prosjekter eller miljøer
- **Abstrahering**: Skjuler kompleksitet bak et enkelt grensesnitt
- **Standardisering**: Sikrer konsistent infrastruktur på tvers av prosjekter
- **Vedlikehold**: Endringer på ett sted propagerer til alle bruksområder

### Root Module vs Child Module

- **Root module**: Hovedkonfigurasjonen i prosjektets rotmappe
- **Child module**: Gjenbrukbare moduler i `modules/`-mappen

Root module kaller child modules og sender inn verdier via variabler:

```hcl
# Root module (main.tf)
module "s3_website" {
  source = "./modules/s3-website"  # Peker til modul-mappen

  # Variabler som sendes til modulen
  bucket_name = "min-bucket"
  subdomain   = "mitt-navn"
}

# Outputs fra modulen brukes slik:
output "website_url" {
  value = module.s3_website.cloudfront_url
}
```

### Provider Configuration i Moduler

I denne oppgaven bruker vi **to AWS providers** (multi-region setup):
- Default provider i `eu-west-1` for S3, CloudFront, etc.
- Aliased provider i `us-east-1` for ACM-sertifikater (CloudFront-krav)

**Viktig**: Du må sende begge providers til modulen eksplisitt. Se [Appendix A: Provider Configuration](#appendix-a-provider-configuration-i-moduler) for detaljert forklaring av hvordan dette fungerer.

**I rot-nivå `main.tf`, send providers til modulen**:

```hcl
module "s3_website" {
  source = "./modules/s3-website"

  providers = {
    aws           = aws           # Default provider
    aws.us-east-1 = aws.us-east-1 # Aliased provider
  }

  bucket_name = var.bucket_name
  subdomain   = var.subdomain
}
```

### Del A: Lag en modul

#### Steg 1: Opprett modul-struktur

Lag mappestrukturen for modulen slik:

```bash
mkdir -p modules/s3-website
touch modules/s3-website/main.tf
touch modules/s3-website/variables.tf
touch modules/s3-website/outputs.tf
```

Dette gir følgende struktur:

```
modules/
└── s3-website/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

#### Steg 2: Definer variabler for modulen

Variabler er det som gjør moduler gjenbrukbare - de lar deg bruke samme modul med ulike verdier for forskjellige miljøer eller brukstilfeller. Uten variabler ville modulen alltid opprette de samme ressursene med de samme verdiene, noe som ville gjøre den ubrukelig for gjenbruk.

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

#### Steg 3: Flytt Ressurser til modulen

**Flytt S3-ressursene** fra root `main.tf` til `modules/s3-website/main.tf`:

- Kopier alle S3-relaterte ressurser (`aws_s3_bucket`, `aws_s3_bucket_website_configuration`, etc.)
- Erstatt hardkodede verdier med `var.bucket_name`, `var.tags`, etc.

**Hint**: I modulen skal du bruke `var.bucket_name` direkte.

#### Steg 4: Definer outputs for modulen

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

### Viktig: Før du bruker modulen - State Management

Før vi refaktorerer koden til å bruke modulen, må vi håndtere et kritisk problem:

**Når du flytter ressurser fra root til en modul, endrer adressene seg:**
- Gammel adresse: `aws_s3_bucket.website`
- Ny adresse: `module.s3_website.aws_s3_bucket.website`

Terraform vil tro at du vil:
1. Slette de gamle ressursene
2. Opprette nye ressurser med samme konfigurasjon

**Resultat**: Din S3 bucket blir slettet og gjenskapt!

### Velg din vei: Red Pill eller Blue Pill?

#### Blue Pill - Den enkle veien

**"Ignorance is bliss"** - Start på nytt med modulen.

1. **Tøm bucketen**:
```bash
aws s3 rm s3://ditt-bucket-navn --recursive
```

2. **Destroy eksisterende infrastruktur**:
```bash
terraform destroy
```

3. **Fortsett til Del B** og bygg opp igjen med modul

**Fordel**: Enkelt og greit
**Ulempe**: Du mister eksisterende data (ok for demo)

---

#### Red Pill - Power Move

**"I want to see how deep the rabbit hole goes"** - Lær Terraform state management!

Terraform har en innebygd måte å håndtere refactoring: `moved` blocks.

**Steg 1**: Før du refaktorerer koden, legg til `moved` blocks i **rot-nivå `main.tf`** (ikke modulens main.tf) som forteller Terraform hvor ressursene skal flyttes.

Disse `moved` blokkene legges til **øverst** i rot-nivå `main.tf`, før de eksisterende ressursene:

```hcl
# Legg til i rot-nivå main.tf FØR du sletter de gamle ressursene
moved {
  from = aws_s3_bucket.website
  to   = module.s3_website.aws_s3_bucket.website
}

moved {
  from = aws_s3_bucket_website_configuration.website
  to   = module.s3_website.aws_s3_bucket_website_configuration.website
}

moved {
  from = aws_s3_bucket_public_access_block.website
  to   = module.s3_website.aws_s3_bucket_public_access_block.website
}

moved {
  from = aws_s3_bucket_policy.website
  to   = module.s3_website.aws_s3_bucket_policy.website
}
```

**Steg 2**: I rot-nivå `main.tf`, erstatt alle S3-ressursene med et modul-kall.

Etter denne endringen skal rot-nivå `main.tf` **kun** inneholde:
- `moved` blokkene fra Steg 1
- Modul-kallet nedenfor
- Eventuelle outputs (som oppdateres i Steg 3)

Slett alle de gamle `resource "aws_s3_..."` blokkene og erstatt dem med:

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

**Steg 3**: Oppdater outputs i root `main.tf` til å bruke module outputs:

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

**Steg 4**: Re-initialiser Terraform for modulen:

```bash
terraform init
```

**Steg 5**: Kjør plan og observer at ressursene flyttes uten å bli gjenskapt:

```bash
terraform plan
```

Du skal nå se linjer som bekrefter at ressursene flyttes i state, for eksempel:

```
# aws_s3_bucket.website has moved to module.s3_website.aws_s3_bucket.website
# aws_s3_bucket_website_configuration.website has moved to module.s3_website.aws_s3_bucket_website_configuration.website
# aws_s3_bucket_public_access_block.website has moved to module.s3_website.aws_s3_bucket_public_access_block.website
# aws_s3_bucket_policy.website has moved to module.s3_website.aws_s3_bucket_policy.website
```

Terraform vil konkludere med: **"No changes. Your infrastructure matches the configuration."**

Dette betyr at `moved` blokkene fungerte - ressursene blir flyttet i state uten å bli slettet og gjenskapt!

**Steg 6**: Apply for å oppdatere state:

```bash
terraform apply
```

**Steg 7**: Når alt fungerer, kan du fjerne `moved` blocks (de trengs ikke lenger)

**Du er nå ferdig!** Red Pill-brukere kan hoppe over Del B nedenfor og gå videre til Del 3: CloudFront CDN.

**Fordel**: Lær avansert Terraform, ingen downtime
**Ulempe**: Krever mer forståelse

---

**Velg din vei**: Blue Pill-brukere fortsetter til Del B nedenfor. Red Pill-brukere hopper til Del 3.

---

### Del B: Bruk modulen (Blue Pill)

**Denne seksjonen er kun for Blue Pill-brukere som valgte å starte på nytt.**

Nå skal du refaktorere root `main.tf` til å bruke modulen du nettopp laget.

#### Din oppgave:

1. **I root `main.tf`**: Erstatt alle S3-ressursene med et modul-kall:

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
terraform init  # Re-initialiser for modulen
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

## Del 3: CloudFront CDN - Minimal Setup

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

  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "S3-${var.bucket_name}"

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = 80
      https_port             = 443
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "S3-${var.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0  # Instant refresh - ingen caching
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
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

## Oppsummering - Part 2

Du har nå lært:

- **Remote State Management**: State deling i team og CI/CD
- **Terraform-moduler**: Gjenbrukbar, DRY infrastruktur-kode
- **CloudFront CDN**: Global distribusjon med HTTPS, minimal kode
- **State Management med moved blocks**: Refaktorering uten downtime

**Neste steg**: Utforsk bonusoppgavene nedenfor for å lære enda mer om GitHub Actions CI/CD, custom domains, og avanserte Terraform-konsepter!

---

## Bonusoppgaver

### 1. GitHub Actions CI/CD Pipeline

#### Mål

Automatiser Terraform deployment:
- **Pull Request**: Kjør `terraform plan` og vis endringer
- **Merge til main**: Kjør `terraform apply` automatisk

#### Steg 1: Opprett Workflow Fil

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
            const output = `### Terraform Plan

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

#### Steg 2: Konfigurer GitHub Secrets

Du må gi GitHub Actions tilgang til AWS:

1. **Gå til ditt GitHub repository**
2. **Settings** → **Secrets and variables** → **Actions**
3. **Klikk "New repository secret"**
4. **Legg til to secrets**:
   - Name: `AWS_ACCESS_KEY_ID`, Value: `<din AWS access key>`
   - Name: `AWS_SECRET_ACCESS_KEY`, Value: `<din AWS secret key>`

**Sikkerhetstips**: Disse secrets bør være fra en dedicated IAM-bruker med minimal permissions (kun det Terraform trenger).

#### Steg 3: Test Pipeline

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

### 2. Custom Domain med Data Sources

#### Hva er Data Sources?

Så langt har vi kun brukt `resource` blokker som **oppretter** nye ressurser i AWS. Men hva hvis vi vil bruke noe som allerede eksisterer? Det er her `data` sources kommer inn.

**Data sources** lar deg **lese** informasjon om eksisterende ressurser uten å endre dem. Tenk på det som:
- `resource` = "Opprett dette" (write)
- `data` = "Hent info om dette" (read-only)

#### Steg 1: Hent eksisterende Hosted Zone

Vi har en delt Route53 hosted zone for domenet `thecloudcollege.com` som du kan bruke. I stedet for å opprette en ny hosted zone, skal vi **hente** den eksisterende med en data source.

**Legg til øverst i `modules/s3-website/main.tf`**:

```hcl
# Data source - henter informasjon om eksisterende hosted zone
data "aws_route53_zone" "main" {
  zone_id = "Z09151061LZNRB9E4BYEL"  # thecloudcollege.com
}
```

#### Steg 2: Hent wildcard ACM-sertifikat fra us-east-1

Vi har et wildcard-sertifikat (`*.thecloudcollege.com`) i `us-east-1` som dekker alle subdomener.

**Legg til i `modules/s3-website/main.tf`**:

```hcl
# Data source - henter eksisterende wildcard ACM-sertifikat
# Bruker us-east-1 provider fordi CloudFront krever sertifikat i denne regionen
data "aws_acm_certificate" "wildcard" {
  provider = aws.us-east-1
  domain   = "*.thecloudcollege.com"
  statuses = ["ISSUED"]
}
```

#### Steg 3: Oppdater CloudFront til å bruke custom domain

Nå må CloudFront konfigureres til å akseptere requests fra ditt custom domain og bruke ACM-sertifikatet for HTTPS.

**Finn `aws_cloudfront_distribution` ressursen** i `modules/s3-website/main.tf` og gjør følgende endringer:

1. **Legg til `aliases` for custom domain** (rett under `enabled` og `default_root_object`):

```hcl
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = ["${var.subdomain}.thecloudcollege.com"]  # NYTT: Custom domain

  # ... resten av konfigurasjonen ...
}
```

2. **Erstatt `viewer_certificate` blokken** (den eksisterende bruker `cloudfront_default_certificate = true`):

```hcl
  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.wildcard.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
```

#### Steg 4: Opprett DNS-record

**Legg til Route53 record** i `modules/s3-website/main.tf`:

```hcl
# Resource - oppretter DNS-record som peker til CloudFront
resource "aws_route53_record" "website" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.subdomain}.thecloudcollege.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}
```

#### Steg 5: Legg til subdomain-variabel

**Legg til i `modules/s3-website/variables.tf`**:

```hcl
variable "subdomain" {
  description = "Subdomain for the website (e.g., 'glenn' becomes glenn.thecloudcollege.com)"
  type        = string
}
```

**Oppdater modul-kallet i root `main.tf`**:

```hcl
module "s3_website" {
  source = "./modules/s3-website"

  bucket_name         = "ditt-bucket-navn"
  website_files_path  = "${path.root}/s3_demo_website"
  subdomain           = "ditt-navn"  # Endre til ditt navn

  tags = {
    Name        = "My Website"
    Environment = "Demo"
  }
}
```

#### Steg 6: Oppdater modul-kallet og outputs

**Oppdater modul-kallet i rot `main.tf`** for å inkludere subdomain og sende providers til modulen (se [Appendix A](#appendix-a-provider-configuration-i-moduler) for detaljer):

```hcl
module "s3_website" {
  source = "./modules/s3-website"

  # Send begge providers til modulen
  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }

  bucket_name         = "ditt-bucket-navn"
  website_files_path  = "${path.root}/s3_demo_website/dist"
  subdomain           = "ditt-navn"  # Endre til ditt unike navn (f.eks. "glenn")

  tags = {
    Name        = "My Website"
    Environment = "Demo"
  }
}
```

**Legg til output i rot `main.tf`**:

```hcl
output "custom_domain_url" {
  value       = module.s3_website.custom_domain_url
  description = "Custom domain URL with HTTPS"
}
```

**Legg til output i `modules/s3-website/outputs.tf`**:

```hcl
output "custom_domain_url" {
  description = "Your custom domain URL"
  value       = "https://${var.subdomain}.thecloudcollege.com"
}
```

**Opprett `modules/s3-website/versions.tf`** for å deklarere forventede providers:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.us-east-1]
    }
  }
}
```

#### Steg 7: Deploy og test

1. **Re-initialiser Terraform** (nødvendig pga. ny provider):

```bash
terraform init
```

2. **Kjør plan** for å se hva som vil bli opprettet/endret:

```bash
terraform plan
```

Du skal se at CloudFront blir oppdatert og at en ny Route53 record blir opprettet.

3. **Apply endringene**:

```bash
terraform apply
```

**Merk**: CloudFront deployment tar 5-15 minutter når konfigurasjonen endres.

4. **Hent din custom domain URL**:

```bash
terraform output custom_domain_url
```

5. **Test din custom domain**:

Vent noen minutter på at CloudFront-distribusjonen er ferdig deployet, og åpne URL-en i nettleseren. Din side vil nå være tilgjengelig på `https://ditt-navn.thecloudcollege.com` med full HTTPS!

**Nøkkelpunkter**:
- **Data sources** lar deg hente informasjon om eksisterende ressurser uten å endre dem
- **Provider alias** (`provider = aws.us-east-1`) lar deg bruke flere regioner i samme konfigurasjon
- CloudFront krever ACM-sertifikater i us-east-1 region
- Route53 `alias` records peker til AWS-ressurser (som CloudFront) uten å bruke IP-adresser
- Data sources refereres med `data.<type>.<name>`, f.eks. `data.aws_route53_zone.main.zone_id`

### 3. Validation Rules på variabler i modulen

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

---

## Ressurser

- [Terraform Modules Documentation](https://developer.hashicorp.com/terraform/language/modules)
- [AWS CloudFront Developer Guide](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/)
- [GitHub Actions Terraform Tutorial](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

---

# Appendix

## Appendix A: Provider Configuration i Moduler

Denne seksjonen gir en grundig forklaring av hvordan Terraform håndterer providers i moduler, spesielt når du trenger å bruke flere AWS-regioner.

### Hvor skal providers konfigureres?

**Best practice**: Provider-konfigurasjon skal være i **root module**, ikke i child modules.

```hcl
# Root module (providers.tf) - RIKTIG
provider "aws" {
  region = "eu-west-1"
}

# Child module - IKKE konfigurer providers her
```

**Hvorfor?**
- Moduler skal være gjenbrukbare på tvers av ulike AWS-kontoer og regioner
- Root module kontrollerer hvilke credentials og regioner som brukes
- Unngår konflikter når modulen brukes flere ganger

### Provider Inheritance

Som standard arver moduler automatisk provider-konfigurasjonen fra root module:

```hcl
# Root module
provider "aws" {
  region = "eu-west-1"
}

module "s3_website" {
  source = "./modules/s3-website"
  # Provider arves automatisk - ingen ekstra konfigurasjon nødvendig
}
```

Dette fungerer utmerket for enkle use cases der du kun trenger én provider-konfigurasjon.

### Multi-Region Setup: Aliased Providers

I denne oppgaven trenger vi **to AWS providers** fordi:
- Hovedressurser (S3, CloudFront) skal være i `eu-west-1`
- ACM-sertifikater for CloudFront **må** være i `us-east-1` (AWS-krav)

#### Steg 1: Definer providers i root module

**Opprett eller oppdater `providers.tf` i rotmappen**:

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# Alias provider for us-east-1
# Nødvendig fordi CloudFront krever ACM-sertifikater i us-east-1
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}
```

**Forklaring**:
- Første `provider "aws"` uten alias er default provider
- Andre `provider "aws"` med `alias = "us-east-1"` er en navngitt provider
- Du kan ha flere aliased providers hvis du trenger flere regioner

#### Steg 2: Send providers til modulen

Når du bruker aliased providers, må du eksplisitt sende dem til modulen:

```hcl
# Root module (main.tf)
module "s3_website" {
  source = "./modules/s3-website"

  # Send begge providers til modulen
  providers = {
    aws           = aws           # Default provider
    aws.us-east-1 = aws.us-east-1 # Aliased provider
  }

  bucket_name = var.bucket_name
  subdomain   = var.subdomain
}
```

**Merk**:
- `aws = aws` sender default provider
- `aws.us-east-1 = aws.us-east-1` sender aliased provider
- Uten `providers`-blokken vil modulen kun få default provider

#### Steg 3: Deklarer forventede providers i modulen

Modulen må eksplisitt deklarere at den forventer en aliased provider:

```hcl
# modules/s3-website/versions.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [aws.us-east-1]
    }
  }
}
```

**`configuration_aliases`** forteller Terraform:
- Denne modulen forventer å motta en aliased provider kalt `aws.us-east-1`
- Root module må sende denne provideren når modulen kalles

#### Steg 4: Bruk providers i ressurser

```hcl
# modules/s3-website/main.tf

# Bruker default provider (eu-west-1) - ingen provider-attributt nødvendig
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name
}

resource "aws_cloudfront_distribution" "website" {
  # Også default provider (eu-west-1)
  enabled = true
  # ...
}

# Bruker eksplisitt aliased provider (us-east-1)
data "aws_acm_certificate" "wildcard" {
  provider = aws.us-east-1  # Eksplisitt spesifisert
  domain   = "*.thecloudcollege.com"
  statuses = ["ISSUED"]
}
```

**Regel**:
- Ressurser **uten** `provider`-attributt bruker default provider
- Ressurser **med** `provider = aws.us-east-1` bruker aliased provider

### Vanlige Feil og Løsninger

#### Feil 1: "Provider configuration not present"

```
Error: Provider configuration not present
Module module.s3_website does not declare a provider named aws.us-east-1
```

**Løsning**: Legg til `configuration_aliases` i `modules/s3-website/versions.tf`.

#### Feil 2: "Module does not support aws.us-east-1"

```
Error: Module does not support aws.us-east-1 provider configuration
```

**Løsning**: Modulen må eksplisitt deklarere at den forventer aliased provider via `configuration_aliases`.

#### Feil 3: Ressurs bruker feil region

**Problem**: ACM-sertifikat blir opprettet i eu-west-1 i stedet for us-east-1.

**Løsning**: Legg til `provider = aws.us-east-1` på ressursen.

### Oppsummering

**For å bruke multi-region providers i moduler**:

1. **Root module**: Definer alle providers (default + aliased) i `providers.tf`
2. **Module call**: Send providers eksplisitt via `providers = { ... }`
3. **Module declaration**: Deklarer forventede providers med `configuration_aliases`
4. **Resources**: Bruk `provider = aws.alias` på ressurser som trenger aliased provider

Dette gir deg full kontroll over hvilke regioner som brukes for hvilke ressurser.
