module SendMessage::TimeLockGovernance {
    use aptos_framework::signer;
    use aptos_framework::timestamp;
    use std::vector;

    /// Error codes
    const E_PROPOSAL_NOT_FOUND: u64 = 1;
    const E_WAITING_PERIOD_NOT_OVER: u64 = 2;
    const E_PROPOSAL_ALREADY_EXECUTED: u64 = 3;
    const E_NOT_AUTHORIZED: u64 = 4;

    /// Struct representing a governance proposal with time lock
    struct Proposal has store, key {
        id: u64,                    // Unique proposal ID
        description: vector<u8>,    // Proposal description
        created_at: u64,           // Timestamp when proposal was created
        waiting_period: u64,       // Mandatory waiting period in seconds
        executed: bool,            // Whether proposal has been executed
        proposer: address,         // Address of the proposer
    }

    /// Global storage for all proposals
    struct GovernanceStorage has key {
        proposals: vector<Proposal>,
        next_proposal_id: u64,
    }

    /// Initialize governance storage
    public fun initialize_governance(admin: &signer) {
        let governance = GovernanceStorage {
            proposals: vector::empty<Proposal>(),
            next_proposal_id: 1,
        };
        move_to(admin, governance);
    }

    /// Function to create a new governance proposal with mandatory waiting period
    public fun create_proposal(
        proposer: &signer, 
        admin_addr: address,
        description: vector<u8>, 
        waiting_period_seconds: u64
    ) acquires GovernanceStorage {
        let proposer_addr = signer::address_of(proposer);
        let governance = borrow_global_mut<GovernanceStorage>(admin_addr);
        
        let proposal = Proposal {
            id: governance.next_proposal_id,
            description,
            created_at: timestamp::now_seconds(),
            waiting_period: waiting_period_seconds,
            executed: false,
            proposer: proposer_addr,
        };
        
        vector::push_back(&mut governance.proposals, proposal);
        governance.next_proposal_id = governance.next_proposal_id + 1;
    }

    /// Function to execute a proposal after the waiting period has passed
    public fun execute_proposal(
        executor: &signer,
        admin_addr: address, 
        proposal_id: u64
    ) acquires GovernanceStorage {
        let governance = borrow_global_mut<GovernanceStorage>(admin_addr);
        let proposals_len = vector::length(&governance.proposals);
        let i = 0;
        
        while (i < proposals_len) {
            let proposal = vector::borrow_mut(&mut governance.proposals, i);
            if (proposal.id == proposal_id) {
                assert!(!proposal.executed, E_PROPOSAL_ALREADY_EXECUTED);
                
                let current_time = timestamp::now_seconds();
                let execution_time = proposal.created_at + proposal.waiting_period;
                assert!(current_time >= execution_time, E_WAITING_PERIOD_NOT_OVER);
                
                proposal.executed = true;
                return
            };
            i = i + 1;
        };
        
        abort E_PROPOSAL_NOT_FOUND
    }
}