"""Read macOS battery/power telemetry without changing power settings.

These are whole-machine IORegistry values, not process energy. Preserve raw
units because PowerTelemetryData is hardware-dependent and undocumented.
"""
import plistlib
import subprocess


def sample_power():
    try:
        result = subprocess.run(
            ['ioreg', '-r', '-n', 'AppleSmartBattery', '-a'],
            capture_output=True, timeout=5, check=True)
        batteries = plistlib.loads(result.stdout)
        if not batteries:
            return {'available': False, 'reason': 'no AppleSmartBattery service'}
        battery = batteries[0]
        fields = ['ExternalConnected', 'IsCharging', 'CurrentCapacity',
                  'MaxCapacity', 'Voltage', 'Amperage', 'InstantAmperage']
        raw = {key: battery[key] for key in fields if key in battery}
        # Some machines encode negative current as unsigned 64-bit integers.
        for key in ['Amperage', 'InstantAmperage']:
            if isinstance(raw.get(key), int) and raw[key] >= 2**63:
                raw[key] -= 2**64
        source = battery.get('PowerTelemetryData', {})
        power = {key: source[key] for key in [
            'SystemPowerIn', 'SystemLoad', 'SystemCurrentIn', 'SystemVoltageIn',
            'BatteryPower', 'SystemEnergyConsumed', 'WallEnergyEstimate',
            'AccumulatedSystemEnergyConsumed', 'PowerTelemetryErrorCount'
        ] if key in source}
        return {'available': True, 'scope': 'whole_machine',
                'units': 'raw_IORegistry', 'battery': raw, 'power': power}
    except (OSError, ValueError, plistlib.InvalidFileException,
            subprocess.SubprocessError) as error:
        return {'available': False, 'reason': str(error)}
