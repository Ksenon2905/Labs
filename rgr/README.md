# Розрахунково-графічна робота
## Тема
## 1. Підготовка GCP для автоматизації
Спочатку створимо проект у GCP, у рамках якого будуть створюватися віртуальні машини і де буде проходити вся подальша автоматизація. Створення проекту було докладно розглянуто у попередніх лабораторних роботах, тому вважаємо, що ми вже маємо певний проект. Також нам треба включити Compute Engine API для роботи із віртуальними машинами.

Наостанок створимо service account для Terraform. Цей шлях ми також проходили у минулих роботах, тому одразу перейдемо до більш цікавих речей.

## 2. Автоматизація створення віртуальної машини

Ми вже докладно розглядали, як автоматизувати створення ВМ за допомогою Terraform, тому зараз ми не будемо розглядати кожну строчку .tf файлу, а просто розкажемо, який конфіг було обрано і обґрунтуємо свій вибір. Отже:

main.tf:
```
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  credentials = file(var.credentials_file)

  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "vpc_network" {
  name = "terrariavpc"
}

resource "google_compute_instance" "vm_instance" {
  name         = var.machine_name
  machine_type = "f1-micro" # Don't need much for small server
  tags         = ["terraria", "jenkins"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-minimal-2210-kinetic-amd64-v20230425"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}

resource "google_compute_firewall" "rules" {
  project       = var.project
  name          = "allowall"
  network       = "terrariavpc"
  description   = "Creates firewall rule targeting tagged instances"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["20", "22", "80", "8080", "7777", "1000-2000"]
  }

  source_tags = ["vpc"]
  target_tags = ["terraria", "jenkins"]
}
```

variables.tf
```
variable "project" {
  default = "vjenkins"
}

variable "credentials_file" {
  default = "creds.json"
}

variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-c"
}

variable "machine_name" {
  default = "terraria-1"
}
```

У даних файлах ми створили ВМ мінімально можливої конфігурації в us-central1-c зоні. Операціною системою є ubuntu cloud. Стосовно останніх рядків: оскільки ми плануємо розгортати застосунок серверу, це значить, що треба вірно сконфігурувати вбудований у GCP брандмауер, щоб він, по-перше, дав доступ по SSH, потім доступ до Jenkins, а по друге, щоб він дозволив роботу на порту сервера (за замовчуванням сервер Terraria працює на порту 7777). Це можна зробити шляхом налаштування ресурсу google_compute_firewall. Окрім того, оскільки ми створили ВМ із тегами, брандмауер був також налаштований на ці теги, щоб не впливати на потенційні інші віртуальні машини.

Тепер ми можемо не боятися блокування наших застосунків, що знаходяться на віртуальній машині. 
Створимо ВМ і мережі командою 
```
terraform apply
```

Результат:
```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

ip_extra = "34.171.74.156"
ip_intra = "10.128.0.2"
```

Машина була створена успішно.

## 3. Налаштування середовища та Jenkins

Зайдемо до ВМ по SSH і зробимо декілька речей.
Спочатку, звісно, треба оновити базу даних менеджеру пакетів apt.

```
sudo apt update
```

Цей крок є опціональним, але для зручності можна поставити собі текстовий редактор nano
```
sudo apt install nano
```
Ті, хто знають, як покинути vim, можуть працювати з ним.

Обов'язково встановлюємо git
```
sudo apt install git
```
### 3.1 Встановлення та налаштування Jenkins
Перед тим, як встановити Jenkins, встановимо Java 11 версії.
```
sudo apt install openjdk-11-jre
```
Тепер встановимо сам Jenkins наступною послідовністю команд (згідно до офіційного мануалу)
```
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt-get update

sudo apt-get install jenkins
```

Далі треба перезавантажитись і Jenkins вже буде готовий до роботи.
Перейдемо за External IP адресою і додамо порт 8080. Відкриється вікно першого налаштування Jenkins. В консолі пишемо
```
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
І активуємо Jenkins. Встановлюємо рекомендуємі плагіни. Дуже рекомендується створити власний обліковий запис. 

Для того, щоб Jenkins міг виконувати дії від імені root, треба зробити наступне в самій ВМ:
```
cd /etc
sudo nano sudoers
```
Там після 
```
# User privilege specification
root    ALL=(ALL:ALL) ALL
```
Додаємо рядок
```
jenkins ALL=NOPASSWD: ALL
```
Це дозволить виконувати команди типу 'sh "sudo..."'

## 3.2 Автоматизація CI/CD

В Jenkins тиснемо "Create a Job" та обираємо Pipeline.

Додаємо опис і тиснемо "Це проект GitHub". Пишемо посилання на наш проект, в нашому випадку це був 
```
https://github.com/vledd/jenkinsterraria
```
Тепер напишемо наш скрипт мовою Groovy. Спочатку подивимося на нього цілком.
```
pipeline 
{
    agent any
    options
    {
        disableConcurrentBuilds()
    }
    stages 
    {
        stage('Download') 
        {
            steps 
            {
                echo "Checkout GO"
                checkout scmGit(
                    branches: [[name: 'main']],
                    userRemoteConfigs: [[url: 'https://github.com/vledd/jenkinsterraria']])
                echo "Checkout OKOK"
            }
        }
        stage('Setup') 
        {
            steps {
                echo "Setup Section GO"
                sh 'chmod +rwx ${WORKSPACE}/1449/Linux/TerrariaServer.bin.x86_64'
                echo "Setup OKOK"
            }
        }
        stage('Run') 
        {
            steps 
            {
            echo "Run GO"
            sh "sudo ${WORKSPACE}/1449/Linux/TerrariaServer.bin.x86_64 -config ${WORKSPACE}/1449/Linux/serverconfig.txt &"
            echo "Run OKOK"
            }
        }
    }
    post 
    {
        success
        {
            echo 'hellyeah'
        }
        failure
        {
            deleteDir()
        }
    }
}
```
Подивимося на те, що сталося.
1. Спочатку ми клонуємо репозиторій із сервером в нашу робочу директорію.
2. Далі ми видаємо права на виконання, читання та запис файлу сервера
3. Далі ми запускаємо сервер від імені root з читанням інформації із конфігураційного файлу. Також ми робимо запуск у фоні.
4. Після збірки виводиться повідомлення. Якщо збірка не вдалася -- тека вичищується.

Обов'язково проставляємо галочки 
1. GitHub hook trigger for GITScm polling
2. SCM Changes (Опрашивать SCM об изменениях)

Спробуємо зробити тестовий білд.
![Build](screenshots/sc1.png)

Він пройшов успішно. Але поки що реакції на оновлення Git ми не отримаємо. Щоб це зробити, до нашого репозиторію потрібно під'єднати вебхуки.
Вони будуть посилати запит до Jenkins при кожному push в репозиторій.
Це робиться в Settings (на сайті GitHub) -> Webhooks -> Add Webhook.

У якості Payload URL вказуємо адресу Jenkins і додаємо /github-webhook/

Приклад
```
http://104.154.232.12:8080/github-webhook/
```
Content type -> application/x-www-form-urlencoded

Інше за замовчуванням.

![Hooks](screenshots/sc2.png)

Тепер спробуємо щось запушити. Наприклад, ми змінимо версію в README.md

Бачимо, що Jenkins сам розпочав зборку.

![Hooks](screenshots/sc3.png)

Після очікування ми отримали успішну зборку, що відбулася без нашої участі (в даному випадку з нашою, але взагалі то пуш до репозиторію можуть робити багато програмістів і Jenkins зможе те обробити).

## 4. Перевірка працездатності

До цього моменту ми довіряли Jenkins і вважали, що все працює вірно. Але треба перевірити, чи дійсно в нас розгорнувся сервер і чи можна до нього під'єднатися.

Спочатку напишемо 
```
top
```
або
```
htop
```
Можемо побачити
```
    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND                                                                                                                                                                   
   1037 root       9 -11 1448088 826060  26384 S 115.0  20.6  10:30.27 Main Thread      
```
Тобто щось працює на фоні. Спробуємо підключитися.

![Радість](screenshots/sc4.png)

Сервер працює без жодних нарікань. Можна грати, а також, якщо щось потрібно буде оновити, можна просто запушати це на GitHub і сервер перезавантажиться сам, розгорнувшись вже з новими налаштуваннями.

## Висновки

![Cossack](screenshots/cossack.png)

У даній РГР ми на практиці застосували всі знання, що набували у межах курса, а саме: Для автоматизації розгортки ВМ нам знадобився Terraform і навички роботи із ним. 
Для автоматизації CI/CD ми скористалися знаннями роботи із Jenkins. Для того, щоб знати, що писати у Terraform, ми скористалися знаннями по GCP. 
Про Git без коментарів: він використовується всюди.

По ітогу в нас вийшло зробити повністю робочий і відносно гнучкий пайплайн з мінімумом ручної роботи (тільки підготовка ВМ до нормального запуску Jenkins і генерація ключів для Terraform).

Після не дуже складної ручної роботи весь проект можна змінювати парою рядків конфігів, якщо мова йде про ВМ, та простим пушем, якщо мова йде про безпосередньо сервер.

### Що додати?

У нас все ще є плацдарм для того, щоб рухатися далі. Те, що бачу я -- можна прикрутити Jenkins CLI. Це дозволить експортувати пайплайни як xml і взагалі розгортати всі додатки одним умовним shell скриптом. Це не було зроблено, оскільки проект є маленьким, а Jenkins CLI це окрема історія, яку треба вивчати, генерувати для неї токени тощо. Але якщо б я адміністрував більш великий проект, я би обов'язково вивчив і прикрутив до нього Jenkins CLI.