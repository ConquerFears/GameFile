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

    Module Synchronization and State Management:

    State Management:
        • Each module should have clear ownership of its state
        • BowState is the single source of truth for tool state
        • Other modules should query BowState rather than tracking their own state
        • Avoid duplicate state tracking across modules
    
    State Transitions:
        • All state transitions must go through BowState:TransitionTo()
        • Modules should react to state changes, not force state changes
        • Always check state validity before transitions
        • Handle edge cases when state changes are rejected
    
    Lifecycle Management:
        • Initialize modules in the correct order: State -> Camera -> UI
        • Cleanup must happen in reverse order of initialization
        • Preserve critical state (like cooldown) across equip/unequip
        • Reset non-critical state properly on cleanup

    Module Interactions:

    Client-Module Communication:
        • Client.client.lua should only interact with public module interfaces
        • Avoid direct state manipulation from Client.client.lua
        • Use events or callbacks for asynchronous operations
        • Keep module APIs consistent and well-documented
    
    Inter-Module Dependencies:
        • Clearly document module dependencies
        • Avoid circular dependencies between modules
        • Use dependency injection where appropriate
        • Keep modules loosely coupled but highly cohesive
    
    Update Cycle:
        • Respect the update order: State -> Camera -> UI
        • Handle frame-dependent operations carefully
        • Use delta time for smooth transitions
        • Avoid expensive operations in update loops

    Common Pitfalls:

    State Desynchronization:
        • Multiple sources modifying the same state
        • Incorrect state restoration after interruptions
        • Missing state cleanup on tool unequip
        • Race conditions in async operations
    
    Camera Issues:
        • Not saving camera state before modifications
        • Incomplete camera state restoration
        • Camera transitions interrupting gameplay
        • FOV changes affecting other tools
    
    UI Timing:
        • UI updates before initialization
        • UI elements persisting after cleanup
        • Incorrect UI state during transitions
        • UI updates during cooldown
    
    Input Handling:
        • Input events during invalid states
        • Multiple input handlers for same action
        • Input state not properly reset
        • Mouse behavior conflicts

    Best Practices:

    Code Organization:
        • Keep modules focused and single-purpose
        • Use clear and consistent naming conventions
        • Document public interfaces and critical functions
        • Group related functionality within modules
    
    Performance:
        • Cache frequently accessed values
        • Minimize garbage collection triggers
        • Use appropriate update frequencies
        • Profile critical paths regularly
    
    Error Handling:
        • Validate all inputs and states
        • Gracefully handle edge cases
        • Provide meaningful error messages
        • Recover from invalid states safely
    
    Testing:
        • Test state transitions thoroughly
        • Verify cleanup and initialization
        • Check edge cases and interruptions
        • Test cross-module interactions

    Maintenance:

    Code Changes:
        • Document all significant changes
        • Update affected module documentation
        • Test changes across all tool states
        • Verify changes don't break existing functionality
    
    Version Control:
        • Use meaningful commit messages
        • Group related changes together
        • Tag significant versions
        • Document breaking changes
    
    Bug Fixes:
        • Address root causes, not symptoms
        • Test fixes across all tool states
        • Document the fix and affected areas
        • Update tests to cover fixed issues
]]--

-- Return empty table since everything is commented
return {} 