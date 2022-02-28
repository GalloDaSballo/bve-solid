import brownie
from brownie import *
from helpers.constants import MaxUint256
from helpers.SnapshotManager import SnapshotManager
from helpers.time import days

"""
  TODO: Put your tests here to prove the strat is good!
  See test_harvest_flow, for the basic tests
  See test_strategy_permissions, for tests at the permissions level
"""

TO_FLATTEN = [
  ["0x6381d38553c8f38FDF4041DBEFA4B4E7B0144DB5"],
  ["0x6381d38553c8f38FDF4041DBEFA4B4E7B0144DB5", "0x6381d38553c8f38FDF4041DBEFA4B4E7B0144DB5"],
  ["0x6381d38553c8f38FDF4041DBEFA4B4E7B0144DB5", "0x6381d38553c8f38FDF4041DBEFA4B4E7B0144DB5", "0x6381d38553c8f38FDF4041DBEFA4B4E7B0144DB5"]
]


LIST_ONE = [
  "0x6381d38553c8f38FDF4041DBEFA4B4E7B0144DB5",
  "0x0FAE367E212f7fCF08D83Ad18Ef1ABa6e009ea42",
  "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  "0x6dAEa54628B659ace75EEd8d62B3f979e0203f9a"
]

LIST_TWO = [
  "0x9C01646Fbf8c38817c4E31A36FE9872388a7d1CB",
  "0xec523df44584c78b4ed331f14b6827eecf29a7d1",
  "0x7289ef5dd4cf676c73b58c939e7ed9f74375b3bd",
  "0xdf241c897a45c301084339abe3ca84d8fd577966",
  "0x6B175474E89094C44Da98b954EedeAC495271d0F",
  "0x295243d962e6e72b6cf0d2602699ebd72c9055cd",
  "0x6cd89f1fefd2a95fb03c46ab3978baf43b0a00cb",
  "0xe68c1d72340aeefe5be76eda63ae2f4bc7514110",
  "0x0fed37c9a19f6919de1f67f05b3451dafaf2955e",
  "0x6cd89f1fefd2a95fb03c46ab3978baf43b0a00cb"
]

def test_quick_sort_works(strategy):
  list_copy = LIST_ONE.copy()
  sorted = strategy.sort(list_copy)
  list_copy.sort()

  assert sorted == list_copy
  assert sorted != LIST_ONE ## Meaningful sort happened

  second_list_copy = LIST_TWO.copy()

  sorted_two = strategy.sort(second_list_copy)
  second_list_copy.sort()

  assert sorted_two == second_list_copy
  assert sorted_two != LIST_TWO ## Meaningful sort happened


def test_flatten_works(strategy):
  flattened = strategy.flatten(TO_FLATTEN)

  assert len(flattened) == 6

def test_no_lock_means_new_lock_on_earn(deployer, want):
  assert False
  

def test_my_custom_test(router, deployer, want):
    assert want.balanceOf(deployer) > 0
    assert True

    ## TODO
    ## Check lock adds lockId
    ## If Lock ID addin adds to lockId

    ## If wait 4 years you can withdraw all

    ## If not wait it always reverts

    ## If not wait but some tokens are liquid you can withdraw up to that

    ## VOTE?
    ## Yield?
    ## Bribes?
