����������� ������ 3

1.������������ Terraform

��� ������������ Terraform ����������� chocolatey:

choco install terraform

ϳ��� ����� ��������� ��������� terraform:

Terraform version

![](screenshots\screen1.png)

2.������������� ��������� ��������� ������

�������� ��������� ������ ��������������. ��� ����� ����� �������� ������� ��:

1)�������� ����� ������:

![](screenshots\screen2.png)

2)�������� ����� ������:

��������� � Dashboard � Service Account. �������� ����� ������ ���������� �� ������ Create Service Account,  ������� ����, ���������� ID � ������ ����.

![](screenshots\screen3.png)

3)�������� ���� ������� 

��������� � Action � Manage keys �� �������� ���� � ������ JSON.

![](screenshots\screen4.png)

4)	��������� terraform

�������� ������ ��������� ��� terraform. ϳ��� ����� �������� 3 �����: main.tf, variables.tf, outputs.tf. �������� ��������� main.tf �� �������� �������������.

��� �������� ��������� ������, �������� ��������� ���:

terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
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
  name = "lab3network"
}

resource "google_compute_subnetwork" "lab3network" {
  name          = var.subnet_name
  network       = google_compute_network.vpc_network.self_link
  ip_cidr_range = "10.2.0.0/16"
  region        = var.region
}


resource "google_compute_instance" "vm_instance" {
  name         = var.machine_name
  machine_type = "f1-micro"
  tags = ["edu", "micro", "linux", "devops", "ukraine"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
    }
  }
}

resource "google_compute_firewall" "vpc-network-allow" {
  name    = "letmein"
  network = google_compute_network.vpc_network.self_link

  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "1000-2000"]
  }
  target_tags = ["http-server","https-server"]
  source_tags = ["vpc-network-allow"]
}


�� ������ ���:
1)����� terraform, �� ���� ��������� �� gcp;

2)���� ������ gcp �� ������ google_compute_subnetwork ��� ���������,  subnetworks. �� ����� ������� ����� lab3network, �������� ���� � ���� � ����� �� vpc �����, �� � ���� ������, � ����� ������ ������� ������, �� ���� ��������� ����� ���������;

3)�������� ��������� ������ � ����������� ������;

4)����������� ���������� ��� ����, ��� �� �������� ������ �� tcp ���������� �� �������� ������ �� ��� �� �������� ������ �� ����������� http �� https.

����� variables.tf �� outputs.tf ���������� ���:
variable "project" {
    default = "lab-3-382613"
}

variable "credentials_file" {
    default = " lab-3-382613-f1f14a12a250.json"
}

variable "region" {
    default = "us-central1"
}

variable "zone" {
    default = "us-central1-c"
}

variable "machine_name" {
    default = "lab-3-382613-1"
}

variable "subnet_name" {
  default = "lab-3-382613-subnet-1"
}

outputs.tf
output "ip_intra" {
  value = google_compute_instance.vm_instance.network_interface.0.network_ip
}

output "ip_extra" {
  value = google_compute_instance.vm_instance.network_interface.0.access_config.0.nat_ip
}

����� ��������� �� �������� ����� ������� �� ��������� �������:

terraform init

�������� ��������:

![](screenshots\screen5.png)

��� ������:

terraform apply

�������� ������ ����, �� ����� ������� terraform:

![](screenshots\screen6.png)

������  "yes" � ������ �� ��������� ��������� ������ � �� ���������.

��� ������ ��������, ��������:

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

ip_extra = "35.193.73.210"
ip_intra = "10.128.0.2"

�������� �� ip-������. ���� � ��� � �������� ������ � VPC ����� Google, � ���� � ������ NAT.

���������� �� ���� ��� ���� ��������:

![](screenshots\screen7.png)
![](screenshots\screen8.png)
![](screenshots\screen9.png)
![](screenshots\screen10.png)

�� ������� ������, �� ������ ���� �������� ��������. 

������� ���� �� ��������:

terraform destroy

![](screenshots\screen11.png)

![](screenshots\screen12.png)

� ��� �� ���������� � ��������� ������, � �����, terraform ������� ��������� ����, ���� �� � �����.
