
1. Dispatcher requests to calculate route for a Transport Order from Frontend
2. Frontend requests to calculate route for a Transport Order from Backend
3. Backend retrieves FRK_TIX based on TA_TIX from TMS Bridge
4. TMS Bridge requests FRK_TIX basewd on TA_TIX from TMS Database
5. TMS Database returns FRK_TX to TMS Bridge
6. TMS Bridge returns FRK_TIX to Backend
7. Backend retrieves PoolDTO for FRK_TIX from TMS Bridge
8. TMS Bridge retrieves PoolDTO from TMS Database via pTop_LoadlingList.get()
9. Backend recieves PoolDTO and calls CalculateRoute in the TOP DLL
10. TOP DLL maps PoolDTO to xServer DTO
11. TOP DLL sends xServer DTO to xServer
12. xServer returns the calculated route to TOP DLL
13. TOP DLL maps xServer DTO to PoolDTO
14. TOP DLL returns PoolDTO to Backend
15. Backend sends PoolDTO to TMS Bridge
16. TMS Bridge sends PoolDTO to TMS Database via pTop_LoadlingList.put()
17. TMS Database runs business logic for updating Tourpoints etc.
18. TMS Database returns successful to Backend
19. Backend returns successful to Frontend
20. Frontend reports success to Dispatcher