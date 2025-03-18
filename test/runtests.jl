using Test
using DiagonalIndexing

# test vectors
# ... get
x = [0.1, 0.2, 0.3]
@test x[diagnl] == [0.1, 0.2, 0.3]


# test matrices
# ... having linear indexing
A = [1 2 3; 4 5 6; 7 8 9; 10 11 12];
@test A[diagnl] == [1, 5, 9]

A[diagnl] = [-1, -5, -9]
@test A == [-1 2 3; 4 -5 6; 7 8 -9; 10 11 12]

@test A[Diagnl(1,0)] == [4, 8, 12]
@test A[Diagnl(0,1)] == [2, 6]

# ... having Cartesian indexing
B = A'
@test B[diagnl] == [-1, -5, -9]


# test higher dimenional arrays
# ...  having linear indexing
T = collect(reshape(0.1:0.1:6.0, (3,4,5)))
@test T[diagnl] == [0.1, 1.7, 3.3]

# ... having Cartesian indexing
S = PermutedDimsArray(T, (3,1,2))
@test S[diagnl] == [0.1, 1.7, 3.3]
