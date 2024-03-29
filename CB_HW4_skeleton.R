#########################################################
#######        COMPUTATIONAL BIOLOGY         ############
#######             HOMEWORK 4               ############
#########################################################
#                                                       #
# Compute the log likelihood of an alignment on a given #
# tree using the Felsenstein's tree-pruning algorithm   #
#########################################################
#########################################################

#########################################################
######    Code below this should not be changed   #######
######    or deleted.                             #######
#########################################################

library(ape)
library(Matrix)

nucleotides = c("T", "C", "A", "G")

get_number_from_nucleotide = function(nuc) {
    # Transform a nucleotide letter into the appropriate number
    return(which(nucleotides == nuc))
}

transform_to_numbers = function(sequence) {
    # Transform a sequence of nucleotide characters into the appropriate number sequence
    num_sequence = simplify2array(lapply(strsplit(sequence, split=c())[[1]], get_number_from_nucleotide))
    return(num_sequence)
}

get_sequence_at_tip_node = function(node, tree, sequences) {
    # Get the sequence at the appropriate tip, represented by a numeric vector
    if (node > length(tree$tip.label)) {
        return(NULL)
    }
    tip_name = tree$tip.label[node]
    sequence = sequences[[tip_name]]
    return(transform_to_numbers(sequence))
}

get_node_children = function(node, tree) {
    # Return the two child nodes of the given node.
    # In a bifurcating tree, a node will have either two child nodes, if it is an internal node,
    # or zero child nodes if it is a tip node.
    # For an internal node, return the two child node numbers and the branch lengths leading to them,
    # for a tip node return NULL.
    #   node: the node for which child nodes should be returned
    #   tree: the tree encoded in an object of class phylo.

    if (node <= length(tree$tip.label)) {
        return(NULL)
    }

    children = which(tree$edge[,1] == node)
    child1 = tree$edge[children[1],2]
    branch_length1 = tree$edge.length[children[1]]
    child2 = tree$edge[children[2],2]
    branch_length2 = tree$edge.length[children[2]]

    # Return the child nodes and the branch lengths leading to them.
    #   child1: first child of the given node
    #   branch_length1: the length of the branch leading to child1
    #   child2: second child of the given node
    #   branch_length2: the length of the branch leading to child2
    return(list(child1 = child1, branch_length1 = branch_length1,
                child2 = child2, branch_length2 = branch_length2))
}

#########################################################
######    Code above this should not be changed   #######
######    or deleted.                             #######
#########################################################

create_TN93_Q_matrix = function(pi, alpha1, alpha2, beta) {
    # Create the TN93 transition rate matrix Q as specified in the assignment.
    # The nucleotide order should be (T, C, A, G).
    #   pi: the stationary frequencies of nucleotides
    #   alpha1: rate coefficient for the C <-> T transition
    #   alpha2: rate coefficient for the A <-> G transition
    #   beta: rate coefficient for transversions
    
    T_index <- get_number_from_nucleotide("T")
    C_index <- get_number_from_nucleotide("C")
    A_index <- get_number_from_nucleotide("A")
    G_index <- get_number_from_nucleotide("G")
    
    a1_pi_c <- alpha1*pi[C_index]
    b_pi_a  <- beta*pi[A_index]
    b_pi_g  <- beta*pi[G_index]
    a1_pi_t <- alpha1*pi[T_index]
    b_pi_t  <- beta*pi[T_index]
    b_pi_c  <- beta*pi[C_index]
    a2_pi_g <- alpha2*pi[G_index]
    a2_pi_a <- alpha2*pi[A_index]
    
    row1 <- c(NA, a1_pi_c, b_pi_a, b_pi_g)
    row2 <- c(a1_pi_t, NA, b_pi_a, b_pi_g)
    row3 <- c(b_pi_t, b_pi_c, NA, a2_pi_g)
    row4 <- c(b_pi_t, b_pi_c, a2_pi_a, NA)
    
    Q <- matrix(nrow = 4, ncol = 4)
    Q[1,] <- row1
    Q[1,1] <- -(Q[1,2]+Q[1,3]+Q[1,4])
    Q[2,] <- row2
    Q[2,2] <- -(Q[2,1]+Q[2,3]+Q[2,4])
    Q[3,] <- row3
    Q[3,3] <- -(Q[3,1]+Q[3,2]+Q[3,4])
    Q[4,] <- row4
    Q[4,4] <- -(Q[4,1]+Q[4,2]+Q[4,3])

    # Return the transition rate matrix
    # Q: 4 by 4 matrix of rates
    return(Q)
}

calculate_likelihood_from_subtree_likelihoods = function(N, Q,
                                                         subtree1_likelihood, subtree1_branch_length,
                                                         subtree2_likelihood, subtree2_branch_length) {
    # Calculate the likelihood of each nucleotide at each site on an internal node, from the two subtree likelihoods.
    #   N: number of sites in the alignment
    #   Q: the substitution rate matrix
    #   subtree1_likelihood: an N by 4 matrix containing the per site per nucleotide likelihoods
    #                        at the first child node
    #   subtree1_branch_length: the length of the branch leading to the first child node
    #   subtree2_likelihood: an N by 4 matrix containing the per site per nucleotide likelihoods
    #                        at the second child node
    #   subtree2_branch_length: the length of the branch leading to the second child node

    
    likelihood_per_site <- matrix(nrow = N, ncol = 4)
  
    for (i in 1:N) {
      for (x in transform_to_numbers("TCAG")) {
        L1 <- 0
        L2 <- 0
        
        for (y in transform_to_numbers("TCAG")) {
          # compute transition probability matrices for the two branch lengths
          P_1 <- expm(Q*subtree1_branch_length)
          P_2 <- expm(Q*subtree2_branch_length)
          
          L1 <- L1 + P_1[x,y]*subtree1_likelihood[i,y]
          L2 <- L2 + P_2[x,y]*subtree2_likelihood[i,y]
        }
        
        likelihood_per_site[i,x] <- L1*L2
      }
    }

    # Return the per site nucleotide likelihoods on the internal node.
    #   likelihood_per_site: an N by 4 matrix representing the nucleotide likelihoods per site
    return(likelihood_per_site)
}

get_likelihood_from_sequence = function(N, sequence) {
    # Get the matrix of likelihoods of each nucleotide at each site at a tip given the sequence at this tip.
    # The matrix should be of size N x 4, where rows represent the sites in the alignment and
    # the columns represent a nucleotide in the order (T, C, A, G).
    # For each site, the likelihood should be 1 in the column representing
    # the nucleotide at this site and 0 in all other columns.
    #   N: number of sites in the alignment
    #   sequence: the sequence at the tip, encoded as a vector of nucleotide numeric values.

    likelihood_per_site <- matrix(nrow = N, ncol = 4)
    for (i in 1:N) {
      likelihood_per_site[i,] <- c(0,0,0,0)
      likelihood_per_site[i, sequence[i]] <- 1
    }

    # Return the per site nucleotide likelihoods at the tip.
    #   likelihood_per_site: an N by 4 matrix representing the nucleotide likelihoods per site
    return(likelihood_per_site)
}

get_subtree_likelihood = function(node, tree, sequences, Q) {
    # Return the matrix of likelihoods per site per nucleotide for the subtree below the given node.
    # The matrix should be of size N x 4, where rows represent the sites in the alignment and
    # the columns represent a nucleotide in the order (T, C, A, G).
    # If the node is a tip, the likelihood per site should be a vector with a 1 in the column representing
    # the nucleotide at this site and 0 in all other columns.
    # Use the get_sequence_at_tip_node function to get the numeric representation of the sequence at the
    # given tip.
    # If the node is an internal node, the likelihood for each nucleotide should be computed
    # from the likelihoods of each of the child subtrees.
    #   node: the node for which likelihoods should be computed
    #   tree: the tree encoded in an object of class phylo
    #   sequences: a list of aligned sequences (as character strings) at the tips of the tree
    #   Q: the substitution rate matrix

    N = nchar(sequences[[1]])

    if (node <= length(tree$tip.label)) {
        # node is a tip: compute the likelihood for each site and each nucleotide on this node

        sequence <- get_sequence_at_tip_node(node = node, tree = tree, sequences = sequences)
        likelihood_per_site <- get_likelihood_from_sequence(N = length(sequence), sequence = sequence)
    } else {
        # node is an internal node: compute the likelihood for each site and each nucleotide on this node

        children <- get_node_children(node = node, tree = tree)
        child1 <- children[["child1"]]
        child2 <- children[["child2"]]
        branch1 <- children[["branch_length1"]]
        branch2 <- children[["branch_length2"]]
        
        subtree1_likelihood <- get_subtree_likelihood(node = child1, tree = tree, sequences = sequences, Q = Q)
        subtree2_likelihood <- get_subtree_likelihood(node = child2, tree = tree, sequences = sequences, Q = Q)
        
        
        likelihood_per_site <- calculate_likelihood_from_subtree_likelihoods(N = N, Q = Q,
                                                                             subtree1_branch_length = branch1,
                                                                             subtree1_likelihood = subtree1_likelihood,
                                                                             subtree2_branch_length = branch2,
                                                                             subtree2_likelihood = subtree2_likelihood)
    }

    # Return the per site nucleotide likelihoods at this node.
    #   likelihood_per_site: an N by 4 matrix representing the nucleotide likelihoods per site
    return(likelihood_per_site)
}

Felstensteins_pruning_loglikelihood = function(pi, alpha1, alpha2, beta, newick_tree, sequences) {
    # Compute the log likelihood of a sequence alignment on the given tree under the TN93 model
    # using Felsenstein's pruning algorithm.
    #   pi: the stationary frequencies of nucleotides
    #   alpha1: rate coefficient for the C <-> T transition
    #   alpha2: rate coefficient for the A <-> G transition
    #   beta: rate coefficient for transversions
    #   newick_tree: the tree in newick text format
    #   sequences: a list of aligned sequences (as character strings) at the tips of the tree
  
    # Transfrom the tree from text format to an object of the phylo class which represents the tree in R
    tree = read.tree(text = newick_tree)
    # Reorder the tree for easier traversing
    tree = reorder(tree, order = "cladewise");
    
    # Number of sites in the alignment
    N = nchar(sequences[[1]])

    # Initialize the Q matrix
    Q <- create_TN93_Q_matrix(pi = pi, alpha1 = alpha1, alpha2 = alpha2, beta = beta)
    
    # Compute the likelihoods per site of the tree starting from the root
    root = length(tree$tip.label) + 1
    likelihood_per_site = get_subtree_likelihood(root, tree, sequences, Q)
    
    # Sum up the log likelihoods of each site
    loglikelihood <- 0
    for (i in 1:N) {
      likelihood <- 0
      for (x in transform_to_numbers("TCAG")) {
        likelihood <- likelihood + pi[x]*likelihood_per_site[i,x]
      }
      loglikelihood <- loglikelihood + log(likelihood)
    }

    # Return the final log likelihood of the alignment on the given tree, a single number computed of the 
    # per site per nucleotide likelihoods at the root of the tree.
    #   loglikelihood: the full log likelihood of the alignment on the tree
    return(loglikelihood)
}

test_tree_loglikelihood = function() {
    beta = 0.00135
    alpha1 = 0.5970915
    alpha2 = 0.2940435
    pi = c(0.22, 0.26, 0.33, 0.19)
    newick_tree = "(unicorn:15,(orangutan:13,(gorilla:10.25,(human:5.5,chimp:5.5):4.75):2.75):2);"
    sequences = list(orangutan = "ACCCCTCCCCTCATGTGTAC",
                     chimp = "ACCCCTCCCCTCATGTGTAC",
                     human = "ACCCCTCCCCTCATGTGTAC",
                     gorilla = "ACCCCTCCCCTCATGTGTAC",
                     unicorn = "TGCCCTCCCCTCATGTGTAC")
    expected_result = -89.4346738736

    result = Felstensteins_pruning_loglikelihood(pi, alpha1, alpha2, beta, newick_tree, sequences)
    print(sprintf("Log likelihood value: %.*f" , 10, result))

    comparison = all.equal(result, expected_result)
    if (isTRUE(comparison)) {
        print("The result matched the expected value.")
    } else {
        print(comparison)
    }
}

test_tree_loglikelihood()
