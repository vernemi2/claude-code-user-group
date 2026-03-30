// eslint-disable-next-line @lwc/lwc/no-async-operation
const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

export { flushPromises };
