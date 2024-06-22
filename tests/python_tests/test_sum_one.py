#import pytest
def sum_one(a, b):
    return a + 2
    
def test_answer():
    assert sum_one(3, 8) == 5
    assert sum_one(3, 2) == 5