# CarWash Management

Modulo aislado dentro del mismo proyecto principal.

## Estructura

- `application/`: coordinacion de estado y reglas de UI.
- `data/`: acceso remoto y repositorios concretos.
- `domain/`: contratos y entidades del dominio CarWash.
- `presentation/`: vistas y widgets del panel.

## Regla de mantenimiento

Las operaciones criticas futuras de CarWash deben entrar por contratos propios del modulo y no por componentes compartidos de otras aplicaciones.
