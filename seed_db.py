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
    
    print("Creating test agents...")
    agents_data = [
        {"username": "agent_alpha", "first": "Jean", "last": "Dupont", "phone": "0102030405", "status": "APPROVED"},
        {"username": "agent_beta", "first": "Marie", "last": "Kone", "phone": "0506070809", "status": "APPROVED"},
        {"username": "agent_gamma", "first": "Paul", "last": "Bamba", "phone": "0708091011", "status": "PENDING"},
        {"username": "agent_delta", "first": "Awa", "last": "Diop", "phone": "0809101112", "status": "REJECTED"},
        {"username": "agent_epsilon", "first": "Luc", "last": "Traore", "phone": "0910111213", "status": "APPROVED", "susp": True},
    ]
    
    agents = []
    for data in agents_data:
        user = User.objects.create_user(username=data["username"], password="password123")
        agent = Agent.objects.create(
            user=user, first_name=data["first"], last_name=data["last"],
            phone_number=data["phone"], kyc_status=data["status"],
            is_suspended=data.get("susp", False)
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
                
    print("Creating transactions...")
    types = ["DEPOT", "RETRAIT", "TRANSFERT", "SWAP"]
    statuses = ["COMPLETED", "PENDING", "FAILED"]
    
    now = timezone.now()
    for _ in range(35):
        agent = random.choice([a for a in agents if a.kyc_status == "APPROVED"])
        tx_type = random.choice(types)
        amount = Decimal(random.randint(10, 1000) * 100) # 1000 to 100000
        status = random.choice(statuses)
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
