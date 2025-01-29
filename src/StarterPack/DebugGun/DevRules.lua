--[[
    DevRules.lua
    Development Rules and Best Practices for Roblox Development
    
    Project Structure:
    DebugGun (Tool)
    ├── Modules/
    │   ├── BowCamera.lua (Camera management)
    │   ├── BowUI.lua (UI elements and effects)
    │   ├── BowState.lua (State machine)
    │   └── BowProjectiles.lua (FastCast and projectile logic)
    ├── FastCastRedux (ModuleScript)
    │   ├── init.lua (Main module)
    │   ├── ActiveCast.lua
    │   ├── Signal.lua
    │   ├── Table.lua
    │   ├── TypeDefinitions.lua
    │   └── TypeMarshaller.lua
    ├── PartCache (ModuleScript)
    │   ├── init.lua (Main module)
    │   └── Table.lua
    ├── Client.client.lua (Client-side logic)
    ├── Server.server.lua (Server-side logic)
    ├── DevRules.lua (this file)
    └── init.meta.json

    Development Rules and Best Practices:
    
    1. Code Organization
        - Keep code modular and separated by concern
        - Use clear, descriptive names for variables and functions
        - Group related functionality into modules
        - Document complex logic with clear comments
        - Use consistent formatting and indentation
        - Each module should have a single responsibility
    
    2. Performance Best Practices
        - Avoid using wait() or delay(), use task.wait() and task.delay() instead
        - Cache frequently accessed services and values
        - Minimize use of Instance.new() in loops, use PartCache for repeated objects
        - Use local variables over global ones
        - Implement proper garbage collection and cleanup
        - Avoid unnecessary replication between client and server
    
    3. Memory Management
        - Clean up connections when they're no longer needed
        - Use :Destroy() on instances that are no longer needed
        - Implement proper cleanup in Tool's Unequipped event
        - Use weak tables when appropriate for event connections
        - Properly manage FastCast instances and projectiles
    
    4. Networking Best Practices
        - Minimize network calls between client and server
        - Implement proper validation on the server
        - Never trust client input without verification
        - Use RemoteEvents for async operations, RemoteFunctions for sync ones
        - Keep network events focused and minimal
    
    5. Security Practices
        - Keep all game logic on the server
        - Validate all client inputs on the server
        - Never expose sensitive calculations to the client
        - Implement anti-exploitation measures
        - Validate projectile physics server-side
    
    6. Error Handling
        - Use pcall() for potentially dangerous operations
        - Implement proper error reporting
        - Add descriptive error messages
        - Handle edge cases gracefully
        - Validate all incoming parameters
    
    7. Tool-Specific Guidelines
        - Implement proper tool state management
        - Handle tool equipped/unequipped states properly
        - Clean up all effects and particles
        - Implement proper cooldowns and anti-spam measures
        - Maintain consistent behavior between client and server
    
    8. Animation and Effects
        - Use tweens instead of loops for smooth animations
        - Pool particles and effects for better performance
        - Clean up effects properly when tool is unequipped
        - Keep effects optimized and minimal
        - Use PartCache for projectile management
    
    9. Physics and Raycasting
        - Use FastCast for projectile calculations
        - Implement proper collision groups
        - Handle edge cases in physics calculations
        - Consider network latency in physics calculations
        - Keep spread and trajectory calculations consistent
    
    10. Testing
        - Test tool in different network conditions
        - Verify behavior with multiple players
        - Test edge cases and error conditions
        - Implement proper debugging tools
        - Validate damage calculations
    
    11. Code Style
        - Use PascalCase for services and classes
        - Use camelCase for variables and functions
        - Use SCREAMING_SNAKE_CASE for constants
        - Add spaces after commas and around operators
        - Keep functions focused and concise
    
    12. Documentation
        - Document all public functions and APIs
        - Keep documentation up to date
        - Include examples in documentation
        - Document known limitations and edge cases
        - Document state machine transitions
]] 