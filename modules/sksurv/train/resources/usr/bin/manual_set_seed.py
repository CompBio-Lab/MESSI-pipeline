# =============================================================================
# Little utilities to use here
# =============================================================================

import random


def set_seed(seed: int):
    """
    Helper function to set the seed in ``random`` and ``numpy`` (and torch
    when installed) for reproducible behavior.
    """
    random.seed(seed)
    np.random.seed(seed)
    try:
        import torch

        torch.manual_seed(seed)
        if torch.cuda.is_available():
            torch.cuda.manual_seed_all(seed)
    except ImportError:
        pass


import numpy as np
