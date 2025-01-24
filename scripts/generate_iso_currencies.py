import csv
import argparse
from collections import defaultdict
from typing import List, Dict, Optional

def read_currency_data(csv_file: str) -> List[Dict]:
    currencies = []
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            currencies.append(row)
    return currencies

def group_by_currency(currencies: List[Dict]) -> Dict[str, List[str]]:
    currency_entities = defaultdict(list)
    for curr in currencies:
        code = curr['AlphabeticCode']
        if code:  # Skip empty codes
            currency_entities[code].append(curr['Entity'])
    return currency_entities

def format_withdrawal_date(date: Optional[str]) -> str:
    return f"[HISTORICAL: {date}]" if date else ""

def generate_proto_enum(currencies: List[Dict], currency_entities: Dict[str, List[str]]) -> str:
    enum_lines = ['enum IsoCurrency {', '  // Placeholder or unspecified currency', '  ISO_CURRENCY_UNSPECIFIED = 0;', '']
    
    # Process each unique currency code
    seen_codes = set()
    for curr in currencies:
        code = curr['AlphabeticCode']
        if not code or code in seen_codes:
            continue
            
        seen_codes.add(code)
        numeric_code = curr['NumericCode']
        if not numeric_code:
            continue
            
        # Get all entities for this currency code
        entities = currency_entities[code]
        entities_str = ', '.join(entities)
        
        # Format withdrawal date if present
        withdrawal_note = format_withdrawal_date(curr['WithdrawalDate'])
        
        # Build the enum entry

        if withdrawal_note:
            enum_lines.append(f'  // - {withdrawal_note}')

        enum_lines.append(f'  // - Currency: {curr["Currency"]} [{code}, {numeric_code}]')

        if curr['MinorUnit']:
            enum_lines.append(f'  // - Decimals: {curr["MinorUnit"]}')

        enum_lines.extend([
            f'  // - Entities: {entities_str}',
            f'  ISO_CURRENCY_{code} = {int(float(numeric_code))};',
            ''
        ])

    # Pop the last empty line and append the closing brace
    enum_lines.pop()
    enum_lines.append('}')
    return '\n'.join(enum_lines)

def main():
    parser = argparse.ArgumentParser(description='Convert ISO 4217 currency CSV to protobuf enum')
    parser.add_argument('input', help='Input CSV file path')
    parser.add_argument('-o', '--output', help='Output proto file path (defaults to stdout)')
    args = parser.parse_args()

    currencies = read_currency_data(args.input)
    currency_entities = group_by_currency(currencies)
    proto_enum = generate_proto_enum(currencies, currency_entities)
    
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(proto_enum)
    else:
        print(proto_enum)

if __name__ == '__main__':
    main()