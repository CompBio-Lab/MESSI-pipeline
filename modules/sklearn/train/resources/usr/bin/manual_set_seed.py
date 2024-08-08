# =============================================================================
# Little utilities to use here
# =============================================================================


# See here: https://stackoverflow.com/questions/70584201/i-dont-understand-why-set-seed-is-needed-with-torch-and-tensorflow-import
# def set_seed(seed: int):
#     """
#     Helper function for reproducible behavior to set the seed in ``random``, ``numpy``, ``torch`` and/or ``tf`` (if
#     installed).

#     Args:
#         seed (:obj:`int`): The seed to set.
#     """
#     random.seed(seed)
#     np.random.seed(seed)
#     if is_torch_available():
#         torch.manual_seed(seed)
#         torch.cuda.manual_seed_all(seed)
        # ^^ safe to call this function even if cuda is not available