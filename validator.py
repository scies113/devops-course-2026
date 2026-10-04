def validate_phone(phone: str) -> bool:
    """Валидация расийского номера."""
    import re
    pattern = r'^\+?7\d{10}$'
    return bool(re.match(pattern, phone.replace('-', '').replace(' ', '')))
# validator.py
def validate_email(email: str) -> bool:
    """Р’Р°Р»РёРґР°С†РёСЏ email-Р°РґСЂРµСЃР°."""
    import re
    pattern = r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$'
    return bool(re.match(pattern, email))


