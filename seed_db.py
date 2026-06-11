import os
import django
import random
from datetime import timedelta
from decimal import Decimal

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.contrib.auth.models import User
from core.models import Agent, Puce, Transaction, CompensationDetail
from django.utils import timezone
import uuid

def run_seeder():
    print("Purging old test data (except admin)...")
    Agent.objects.all().delete()
    User.objects.filter(is_staff=False).delete()
    
    print("Creating 100 test agents...")
    agents = []
    statuses = ["APPROVED"] * 80 + ["PENDING"] * 10 + ["REJECTED"] * 5 + ["APPROVED"] * 5 # with 5 suspended
    random.shuffle(statuses)
    
    first_names = ["Jean", "Marie", "Paul", "Awa", "Luc", "Fatou", "Kouakou", "Seydou", "Bintou", "Moussa"]
    last_names = ["Dupont", "Kone", "Bamba", "Diop", "Traore", "Ouattara", "Toure", "Cisse", "Diallo", "Keita"]
    
    for i in range(100):
        status = statuses[i]
        is_suspended = (status == "APPROVED" and i >= 95)
        user = User.objects.create_user(username=f"agent_{i+1}", password="password123")
        agent = Agent.objects.create(
            user=user, 
            first_name=random.choice(first_names), 
            last_name=random.choice(last_names),
            phone_number=f"0{random.randint(100000000, 999999999)}", 
            kyc_status=status,
            is_suspended=is_suspended
        )
        agents.append(agent)
    
    print("Creating puces for approved agents...")
    operators = ["Orange", "Moov", "MTN", "Wave"]
    puces = []
    for agent in agents:
        if agent.kyc_status == "APPROVED":
            for _ in range(random.randint(1, 3)):
                puce = Puce.objects.create(
                    agent=agent, operator=random.choice(operators),
                    phone_number=f"0{random.randint(10000000, 99999999)}",
                    balance=Decimal(random.randint(50000, 1000000))
                )
                puces.append(puce)
                
    print("Creating 500 transactions...")
    types = ["DEPOT", "RETRAIT", "TRANSFERT", "SWAP"]
    statuses_list = ["COMPLETED", "PENDING", "FAILED"]
    
    now = timezone.now()
    for _ in range(500):
        agent = random.choice([a for a in agents if a.kyc_status == "APPROVED"])
        tx_type = random.choice(types)
        amount = Decimal(random.randint(10, 1000) * 100) # 1000 to 100000
        status = random.choice(statuses_list)
        # 80% completed
        if random.random() < 0.8:
            status = "COMPLETED"
            
        tx_date = now - timedelta(days=random.randint(0, 10), hours=random.randint(0, 23))
        commission = amount * Decimal('0.015') # 1.5% commission
        
        tx = Transaction.objects.create(
            agent=agent, type=tx_type, status=status, amount=amount,
            target_operator=random.choice(operators),
            target_phone_number=f"0{random.randint(10000000, 99999999)}",
            is_compensated=(tx_type in ["DEPOT", "TRANSFERT", "SWAP"]),
            commission_sic=commission if status == "COMPLETED" else 0
        )
        # Override created_at for chronological spread
        Transaction.objects.filter(id=tx.id).update(created_at=tx_date)
        
        # Add compensation details if compensated
        if tx.is_compensated and agent.puces.exists():
            puce = random.choice(agent.puces.all())
            ref = f"CPAY_{uuid.uuid4().hex[:8].upper()}"
            cd = CompensationDetail.objects.create(
                transaction=tx, puce=puce, amount_deducted=amount,
                status="SUCCESS" if status == "COMPLETED" else "PENDING",
                cinetpay_ref=ref
            )
            CompensationDetail.objects.filter(id=cd.id).update(created_at=tx_date)

    print("Database seeding completed successfully!")

if __name__ == '__main__':
    run_seeder()
