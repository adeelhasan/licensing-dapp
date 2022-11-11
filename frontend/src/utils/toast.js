import { toast } from 'react-toastify'

const toastConfig = {
  position: 'bottom-center',
  autoClose: 5000,
  hideProgressBar: false,
  closeOnClick: true,
  pauseOnHover: true,
  draggable: true,
  progress: undefined,
}

export const toastSuccessMessage = (message) =>
  toast.success(message, toastConfig)
export const toastErrorMessage = (message) =>
  toast.error(message, toastConfig)
